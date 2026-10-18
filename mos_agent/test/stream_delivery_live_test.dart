import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mos_agent/features/chats/application/chat_controller.dart';
import 'package:mos_agent/features/chats/domain/chat.dart';
import 'package:mos_agent/features/chats/domain/inference_backend.dart';
import 'package:mos_agent/integrations/inference/http_inference_backend.dart';

/// Observe transport timing without logging message content or request URLs.
class DeliveryTiming {
  final clock = Stopwatch();
  final wireTimes = <double>[];
  final textTimes = <double>[];
  int bytes = 0;
  double? headersMs;
  double get milliseconds => clock.elapsedMicroseconds / 1000;
}

class TimingClient extends http.BaseClient {
  TimingClient(this.timing) : _inner = http.Client();
  final DeliveryTiming timing;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final observing = request.url.pathSegments.contains('send');
    if (observing) timing.clock.start();
    final response = await _inner.send(request);
    if (!observing) return response;
    timing.headersMs = timing.milliseconds;
    return http.StreamedResponse(
      response.stream.map((chunk) {
        timing.wireTimes.add(timing.milliseconds);
        timing.bytes += chunk.length;
        return chunk;
      }),
      response.statusCode,
      headers: response.headers,
      request: response.request,
      reasonPhrase: response.reasonPhrase,
      persistentConnection: response.persistentConnection,
      isRedirect: response.isRedirect,
      contentLength: response.contentLength,
    );
  }

  @override
  void close() => _inner.close();
}

void main() {
  test(
    'Measure transport chunks and incremental controller updates',
    () async {
      final timing = DeliveryTiming();
      final controller = ChatController(
        backend: HttpInferenceBackend(
          destination: Uri.parse(
            const String.fromEnvironment(
              'INFERENCE_BASE_URL',
              defaultValue: 'http://127.0.0.1:8000',
            ),
          ),
          clientFactory: () => TimingClient(timing),
        ),
      );
      addTearDown(controller.dispose);
      await controller.connect();
      expect(
        controller.status,
        BackendStatus.ready,
        reason: controller.connectionError,
      );
      var previousLength = 0;
      controller.addListener(() {
        final messages = controller.active.messages;
        if (messages.isEmpty ||
            messages.last.delivery != MessageDelivery.streaming) {
          return;
        }
        final length = messages.last.text.length;
        if (length > previousLength) {
          timing.textTimes.add(timing.milliseconds);
          previousLength = length;
        }
      });
      final id = controller.active.id;
      controller.updateDraft(
        id,
        'Explain eight steps for organizing a help desk knowledge base. Give at least three sentences for every step.',
      );
      expect(
        await controller.send(id),
        isTrue,
        reason: controller.active.error,
      );
      final end = timing.milliseconds;
      timing.clock.stop();
      expect(timing.wireTimes, isNotEmpty);
      expect(timing.textTimes, isNotEmpty);
      // Deliberately report observed timing instead of asserting chunk cadence:
      // HTTP chunked transfer alone does not promise incremental generation.
      // ignore: avoid_print
      print(
        jsonEncode({
          'headers_ms': timing.headersMs,
          'wire_chunks': timing.wireTimes.length,
          'first_wire_ms': timing.wireTimes.first,
          'last_wire_ms': timing.wireTimes.last,
          'wire_delivery_span_ms':
              timing.wireTimes.last - timing.wireTimes.first,
          'streaming_text_updates': timing.textTimes.length,
          'first_text_ms': timing.textTimes.first,
          'last_text_ms': timing.textTimes.last,
          'first_text_after_first_wire_ms':
              timing.textTimes.first - timing.wireTimes.first,
          'completion_ms': end,
          'response_bytes': timing.bytes,
        }),
      );
    },
    skip: !const bool.fromEnvironment('LIVE_INFERENCE'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
