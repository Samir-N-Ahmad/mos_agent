import 'package:flutter_test/flutter_test.dart';
import 'package:mos_agent/features/chats/application/chat_controller.dart';
import 'package:mos_agent/features/chats/domain/inference_backend.dart';
import 'package:mos_agent/integrations/inference/http_inference_backend.dart';

void main() {
  test(
    'Local service completes startup, creates a chat, and streams a synthetic answer',
    () async {
      final backend = HttpInferenceBackend(
        destination: Uri.parse(
          const String.fromEnvironment(
            'INFERENCE_BASE_URL',
            defaultValue: 'http://127.0.0.1:8000',
          ),
        ),
      );
      final controller = ChatController(backend: backend);
      addTearDown(controller.dispose);
      await controller.connect();
      expect(
        controller.status,
        BackendStatus.ready,
        reason: controller.connectionError,
      );
      final id = controller.active.id;
      controller.updateDraft(id, 'Reply with one short greeting.');
      expect(
        await controller.send(id),
        isTrue,
        reason: controller.active.error,
      );
      final answer = controller.active.messages.last.text;
      expect(answer, isNotEmpty);
      expect(answer, isNot(contains('<|im_start|>')));
      expect(answer, isNot(contains('text classification model')));
      expect(controller.active.draft, isEmpty);
      final classification = controller.modes.firstWhere(
        (mode) => mode.name.toUpperCase() == 'CLASSIFICATION',
      );
      await controller.newChat(mode: classification);
      expect(controller.active.mode, classification);
      expect(controller.connectionError, isNull);
      final classificationId = controller.active.id;
      controller.updateDraft(classificationId, 'My printer is not working.');
      expect(
        await controller.send(classificationId),
        isTrue,
        reason: controller.active.error,
      );
      final token = controller.active.messages.last.text.trim();
      expect(token, isNotEmpty);
      expect(token.split(RegExp(r'\s+')), hasLength(1));
    },
    skip: !const bool.fromEnvironment('LIVE_INFERENCE'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
