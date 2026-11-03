import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../features/chats/domain/inference_backend.dart';
import '../../features/chats/domain/chat.dart';
import 'assistant_text_stream.dart';
import '../../core/diagnostics/app_log.dart';

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

  Future<Object?> _getJson(
    List<String> segments, {
    String method = 'GET',
    Map<String, String>? queryParameters,
  }) async {
    final client = _client();
    final route = segments.first == 'cancel'
        ? '/cancel/{chat_id}/'
        : '/${segments.join('/')}';
    final operation = '$method $route';
    AppLog.instance.add('API request', operation);
    try {
      final response = await client
          .send(
            http.Request(
              method,
              _uri(segments).replace(queryParameters: queryParameters),
            )..followRedirects = false,
          )
          .timeout(requestTimeout);
      AppLog.instance.add(
        'API status',
        '$operation → HTTP ${response.statusCode}',
      );
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
      AppLog.instance.add('API raw response', body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _status(response.statusCode);
      }
      final value = jsonDecode(body);
      if (value is Map && value['code'] != null && value['code'] != 200) {
        throw const InferenceFailure(
          InferenceFailureKind.server,
          'The service reported an unsuccessful operation.',
        );
      }
      return value;
    } on InferenceFailure catch (error) {
      AppLog.instance.add('API error', error.message);
      rethrow;
    } on TimeoutException {
      AppLog.instance.add('API error', 'Request timed out');
      throw const InferenceFailure(
        InferenceFailureKind.timeout,
        'The inference service timed out. The operation may still be running.',
      );
    } on FormatException {
      AppLog.instance.add('API error', 'Invalid JSON response');
      throw const InferenceFailure(
        InferenceFailureKind.protocol,
        'The service returned invalid JSON.',
      );
    } catch (error) {
      AppLog.instance.add('API error', error.runtimeType.toString());
      throw const InferenceFailure(
        InferenceFailureKind.connection,
        'Could not reach the inference service. Check that it is running.',
      );
    } finally {
      client.close();
      _clients.remove(client);
    }
  }

  Future<void> _recordErrorBody(http.StreamedResponse response) async {
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in response.stream.timeout(streamTimeout)) {
        final remaining = 64 * 1024 - bytes.length;
        bytes.add(chunk.take(remaining).toList());
        if (bytes.length >= 64 * 1024) break;
      }
      AppLog.instance.add(
        'API raw error response',
        utf8.decode(bytes.takeBytes(), allowMalformed: true),
      );
    } catch (_) {
      AppLog.instance.add(
        'API raw error response',
        'Error body could not be read completely.',
      );
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
    AppLog.instance.add(
      'API request',
      'GET /send/{chat_id}/{message} · prompt omitted',
    );
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
      AppLog.instance.add(
        'API stream status',
        'HTTP ${response.statusCode} · ${response.headers['content-type']}',
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _recordErrorBody(response);
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
          .transform(utf8.decoder)
          .map((raw) {
            AppLog.instance.add('API raw stream', raw);
            return raw;
          });
      await for (final delta in assistantTextStream(
        text,
        userMessage: message,
      )) {
        if (delta.isNotEmpty) {
          hasText = true;
          yield delta;
        }
      }
      AppLog.instance.add('API stream', 'Stream completed');
      if (deadlineReached) throw TimeoutException('Run deadline');
      if (!hasText) {
        throw const InferenceFailure(
          InferenceFailureKind.protocol,
          'The inference service returned an empty response.',
        );
      }
    } on InferenceFailure catch (error) {
      AppLog.instance.add('API error', error.message);
      rethrow;
    } on TimeoutException {
      AppLog.instance.add('API error', 'Request timed out');
      throw const InferenceFailure(
        InferenceFailureKind.timeout,
        'Response timed out. The server may still be processing; your draft is kept.',
      );
    } catch (error) {
      AppLog.instance.add('API error', error.runtimeType.toString());
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
  Future<bool> cancelGeneration(String chatId) async {
    // The deployed handler currently declares chatId as a query parameter.
    // Supply both forms once; do not retry a potentially committed POST.
    final value = await _getJson(
      ['cancel', chatId, ''],
      method: 'POST',
      queryParameters: {'chatId': chatId},
    );
    if (value is! Map || value['code'] != 200 || value['inference'] is! bool) {
      throw const InferenceFailure(
        InferenceFailureKind.protocol,
        'The service did not return a boolean cancellation result.',
      );
    }
    return value['inference'] as bool;
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
