import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/chats/domain/inference_backend.dart';
import '../../features/chats/domain/chat.dart';
import 'assistant_text_stream.dart';

class HttpInferenceBackend implements InferenceBackend {
  HttpInferenceBackend({
    required this.destination,
    http.Client Function()? clientFactory,
    this.requestTimeout = const Duration(seconds: 60),
    this.streamTimeout = const Duration(seconds: 60),
    this.runTimeout = const Duration(minutes: 3),
    this.maxResponseBytes = 1024 * 1024,
  }) : _clientFactory = clientFactory ?? http.Client.new {
    if ((destination.scheme != 'http' && destination.scheme != 'https') ||
        destination.host.isEmpty ||
        destination.userInfo.isNotEmpty ||
        destination.hasQuery ||
        destination.hasFragment) {
      throw ArgumentError(
        'Use an HTTP(S) backend URL without credentials, query, or fragment.',
      );
    }
  }

  @override
  final Uri destination;
  final http.Client Function() _clientFactory;
  final Duration requestTimeout;
  final Duration streamTimeout;
  final Duration runTimeout;
  final int maxResponseBytes;
  final Set<http.Client> _clients = {};
  final Map<String, http.Client> _streams = {};
  bool _closed = false;

  Uri _uri(List<String> segments) => destination.replace(
    pathSegments: [
      ...destination.pathSegments.where((part) => part.isNotEmpty),
      ...segments,
    ],
  );

  http.Client _client() {
    if (_closed) {
      throw const InferenceFailure(
        InferenceFailureKind.connection,
        'Connection is closed.',
      );
    }
    final client = _clientFactory();
    _clients.add(client);
    return client;
  }

  InferenceFailure _status(int status) => InferenceFailure(
    switch (status) {
      401 || 403 => InferenceFailureKind.authentication,
      400 || 404 || 405 || 413 || 414 || 422 => InferenceFailureKind.validation,
      429 => InferenceFailureKind.rateLimit,
      _ => InferenceFailureKind.server,
    },
    switch (status) {
      401 || 403 => 'The inference service requires authorization.',
      414 => 'This message is too long for the backend URL. Shorten it and try again.',
      429 =>
        'The inference service is rate limited. Wait before sending again.',
      _ => 'The inference service returned HTTP $status.',
    },
  );

  Future<Object?> _getJson(List<String> segments) async {
    final client = _client();
    try {
      final response = await client
          .send(http.Request('GET', _uri(segments))..followRedirects = false)
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _status(response.statusCode);
      }
      var count = 0;
      final body = await response.stream
          .map((bytes) {
            count += bytes.length;
            if (count > 64 * 1024) {
              throw const InferenceFailure(
                InferenceFailureKind.protocol,
                'The service returned an oversized status response.',
              );
            }
            return bytes;
          })
          .transform(utf8.decoder)
          .join()
          .timeout(requestTimeout);
      final value = jsonDecode(body);
      if (value is Map && value['code'] != null && value['code'] != 200) {
        throw const InferenceFailure(
          InferenceFailureKind.server,
          'The service reported an unsuccessful operation.',
        );
      }
      return value;
    } on InferenceFailure {
      rethrow;
    } on TimeoutException {
      throw const InferenceFailure(
        InferenceFailureKind.timeout,
        'The inference service timed out. The operation may still be running.',
      );
    } on FormatException {
      throw const InferenceFailure(
        InferenceFailureKind.protocol,
        'The service returned invalid JSON.',
      );
    } catch (_) {
      throw const InferenceFailure(
        InferenceFailureKind.connection,
        'Could not reach the inference service. Check that it is running.',
      );
    } finally {
      client.close();
      _clients.remove(client);
    }
  }

  @override
  Future<void> start() async {
    final value = await _getJson(['inference', 'start']);
    if (value is! Map ||
        value['code'] != 200 ||
        value['inference'] != 'Started') {
      throw const InferenceFailure(
        InferenceFailureKind.protocol,
        'The service did not confirm inference startup.',
      );
    }
  }

  @override
  Future<List<ChatMode>> fetchModes() async {
    final response = await _getJson(['inference', 'modes']);
    const invalid = InferenceFailure(
      InferenceFailureKind.protocol,
      'The service returned an invalid or empty mode catalogue. No chat was created.',
    );
    if (response is! Map ||
        response['code'] != 200 ||
        response['modes'] is! List) {
      throw invalid;
    }
    final entries = response['modes'] as List;
    if (entries.isEmpty || entries.length > 64) throw invalid;
    final modes = <ChatMode>[];
    final values = <String>{};
    for (final entry in entries) {
      if (entry is! Map) throw invalid;
      final name = entry['name'];
      final value = entry['value'];
      if (name is! String ||
          name.trim().isEmpty ||
          name.length > 128 ||
          (value is! int && value is! String)) {
        throw invalid;
      }
      final encodedValue = value.toString();
      if (encodedValue.trim().isEmpty ||
          encodedValue.length > 128 ||
          encodedValue.contains('/') ||
          !values.add(encodedValue)) {
        throw invalid;
      }
      modes.add(ChatMode(name: name, value: encodedValue));
    }
    return List.unmodifiable(modes);
  }

  @override
  Future<String> newChat({required ChatMode mode}) async {
    final value = await _getJson(['chat', 'new', mode.value]);
    if (value is! Map || value['code'] != 200) {
      throw const InferenceFailure(
        InferenceFailureKind.protocol,
        'The service did not return a chat ID.',
      );
    }
    final id = value['inference'];
    if (id is int && id >= 0) return id.toString();
    if (id is String && id.trim().isNotEmpty) return id;
    throw const InferenceFailure(
      InferenceFailureKind.protocol,
      'The service returned an invalid chat ID.',
    );
  }

  @override
  Stream<String> send(String chatId, String message) async* {
    if (message.contains('/')) {
      throw const InferenceFailure(
        InferenceFailureKind.validation,
        'This backend route cannot accept "/" in messages. Your draft is kept. The service needs a message-body endpoint to support this text.',
      );
    }
    final client = _client();
    _streams[chatId] = client;
    var deadlineReached = false;
    final deadline = Timer(runTimeout, () {
      deadlineReached = true;
      client.close();
    });
    try {
      final request = http.Request('GET', _uri(['send', chatId, message]))
        ..followRedirects = false;
      request.headers['Accept'] = 'text/plain';
      request.headers['Cache-Control'] = 'no-store';
      final response = await client.send(request).timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _status(response.statusCode);
      }
      final type = response.headers['content-type']?.split(';').first.trim();
      if (type != 'text/plain') {
        throw const InferenceFailure(
          InferenceFailureKind.protocol,
          'Expected a plain-text response stream from the inference service.',
        );
      }
      var count = 0;
      var hasText = false;
      final text = response.stream
          .timeout(streamTimeout)
          .map((bytes) {
            count += bytes.length;
            if (count > maxResponseBytes) {
              throw const InferenceFailure(
                InferenceFailureKind.protocol,
                'Response limit reached. The displayed response may be incomplete.',
              );
            }
            return bytes;
          })
          .transform(utf8.decoder);
      await for (final delta in assistantTextStream(
        text,
        userMessage: message,
      )) {
        if (delta.isNotEmpty) {
          hasText = true;
          yield delta;
        }
      }
      if (deadlineReached) throw TimeoutException('Run deadline');
      if (!hasText) {
        throw const InferenceFailure(
          InferenceFailureKind.protocol,
          'The inference service returned an empty response.',
        );
      }
    } on InferenceFailure {
      rethrow;
    } on TimeoutException {
      throw const InferenceFailure(
        InferenceFailureKind.timeout,
        'Response timed out. The server may still be processing; your draft is kept.',
      );
    } catch (_) {
      throw InferenceFailure(
        deadlineReached
            ? InferenceFailureKind.timeout
            : InferenceFailureKind.connection,
        'Response interrupted. The request may have reached the server; your draft is kept.',
      );
    } finally {
      deadline.cancel();
      client.close();
      _clients.remove(client);
      if (_streams[chatId] == client) _streams.remove(chatId);
    }
  }

  @override
  void stopReceiving(String chatId) => _streams.remove(chatId)?.close();

  @override
  void close() {
    _closed = true;
    for (final client in _clients.toList()) {
      client.close();
    }
    _clients.clear();
    _streams.clear();
  }
}
