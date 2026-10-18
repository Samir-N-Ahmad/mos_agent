import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mos_agent/features/chats/application/chat_controller.dart';
import 'package:mos_agent/features/chats/domain/chat.dart';
import 'package:mos_agent/integrations/inference/http_inference_backend.dart';

void main() {
  test(
    'HTTP transport, decoder and controller emit partial answers before EOF',
    () async {
      final wire = StreamController<List<int>>();
      final listening = Completer<void>();
      final backend = HttpInferenceBackend(
        destination: Uri.parse('http://127.0.0.1:8000'),
        clientFactory: () => MockClient.streaming((request, body) async {
          if (request.url.path.startsWith('/send/')) {
            listening.complete();
            return http.StreamedResponse(
              wire.stream,
              200,
              headers: {'content-type': 'text/plain; charset=utf-8'},
            );
          }
          final payload = switch (request.url.path) {
            '/inference/start' => '{"code":200,"inference":"Started"}',
            '/inference/modes' =>
              '{"code":200,"modes":[{"name":"CHAT","value":1}]}',
            '/chat/new/1' => '{"code":200,"inference":0}',
            _ => throw StateError('Unexpected request'),
          };
          return http.StreamedResponse(Stream.value(utf8.encode(payload)), 200);
        }),
      );
      final controller = ChatController(backend: backend);
      addTearDown(controller.dispose);
      await controller.connect();
      controller.updateDraft(controller.active.id, 'Hello');
      final firstUpdate = Completer<void>();
      final secondUpdate = Completer<void>();
      controller.addListener(() {
        if (controller.active.messages.isEmpty) return;
        final text = controller.active.messages.last.text;
        if (text == 'First part' && !firstUpdate.isCompleted) {
          firstUpdate.complete();
        }
        if (text == 'First part and second part' && !secondUpdate.isCompleted) {
          secondUpdate.complete();
        }
      });
      final pending = controller.send(controller.active.id);
      await listening.future;
      wire.add(
        utf8.encode(
          '<|im_start|>system\nPrivate prompt<|im_end|>\n<|im_start|>user\nHello<|im_end|>\n<|im_start|>assis',
        ),
      );
      wire.add(utf8.encode('tant\nFirst part'));
      await firstUpdate.future.timeout(const Duration(seconds: 5));
      expect(controller.active.messages.last.text, 'First part');
      expect(controller.active.sending, isTrue);
      expect(
        controller.active.messages.last.delivery,
        MessageDelivery.streaming,
      );
      expect(controller.active.draft, 'Hello');

      wire.add(utf8.encode(' and second part'));
      await secondUpdate.future.timeout(const Duration(seconds: 5));
      expect(
        controller.active.messages.last.text,
        'First part and second part',
      );
      expect(controller.active.sending, isTrue);

      wire.add(utf8.encode('<|im_end|>'));
      await wire.close();
      expect(await pending.timeout(const Duration(seconds: 5)), isTrue);
      expect(
        controller.active.messages.last.text,
        'First part and second part',
      );
      expect(
        controller.active.messages.last.delivery,
        MessageDelivery.complete,
      );
      expect(controller.active.sending, isFalse);
      expect(controller.active.draft, isEmpty);
    },
  );
}
