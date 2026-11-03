import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mos_agent/features/chats/application/chat_controller.dart';
import 'package:mos_agent/features/chats/domain/inference_backend.dart';
import 'package:mos_agent/integrations/inference/http_inference_backend.dart';

class GenerationHeaderClient extends http.BaseClient {
  GenerationHeaderClient(this.generationReady);
  final Completer<void> generationReady;
  final http.Client _inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (request.url.pathSegments.firstOrNull == 'send' &&
        !generationReady.isCompleted) {
      generationReady.complete();
    }
    return response;
  }

  @override
  void close() => _inner.close();
}

void main() {
  test(
    'Cancel an in-flight synthetic generation through the actual controller',
    () async {
      final generationReady = Completer<void>();
      final controller = ChatController(
        backend: HttpInferenceBackend(
          destination: Uri.parse(
            const String.fromEnvironment(
              'INFERENCE_BASE_URL',
              defaultValue: 'http://127.0.0.1:8000',
            ),
          ),
          clientFactory: () => GenerationHeaderClient(generationReady),
        ),
      );
      addTearDown(controller.dispose);
      await controller.connect();
      expect(
        controller.status,
        BackendStatus.ready,
        reason: controller.connectionError,
      );
      final id = controller.active.id;
      controller.updateDraft(
        id,
        'Write a long guide with twenty detailed paragraphs about organizing a help desk knowledge base.',
      );
      final send = controller.send(id);
      await generationReady.future.timeout(const Duration(seconds: 30));
      final watch = Stopwatch()..start();
      await controller.cancelGeneration(id);
      watch.stop();
      final confirmed =
          controller.active.notice?.startsWith('Generation cancelled.') ??
          false;
      // ignore: avoid_print
      print(
        jsonEncode({
          'cancel_confirmed': confirmed,
          'cancel_ms': watch.elapsedMilliseconds,
          'error': controller.active.error,
          'notice': controller.active.notice,
        }),
      );
      expect(
        confirmed,
        isTrue,
        reason: controller.active.error ?? controller.active.notice,
      );
      expect(await send.timeout(const Duration(seconds: 10)), isFalse);
      expect(controller.active.draft, isNotEmpty);
      expect(controller.active.cancelling, isFalse);
    },
    skip: !const bool.fromEnvironment('LIVE_CANCELLATION'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
