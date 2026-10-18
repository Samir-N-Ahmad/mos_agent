import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mos_agent/features/chats/application/chat_controller.dart';
import 'package:mos_agent/features/chats/domain/chat.dart';

class ControlledResponder implements ChatResponder {
  final result = Completer<ChatMessage>();
  int calls = 0;
  @override
  Future<ChatMessage> respond(ChatThread thread, ChatMessage message) {
    calls++;
    return result.future;
  }
}

void main() {
  test('Drafts, files, and configuration stay scoped to their chat', () {
    final controller = ChatController();
    addTearDown(controller.dispose);
    final first = controller.active.id;
    controller.updateDraft(first, 'My first draft');
    const file = ChatAttachment(path: '/demo/report.txt', name: 'report.txt');
    controller.addAttachments(first, [file, file]);
    controller.configure(
      first,
      role: AgentRole.triage,
      style: ReplyStyle.detailed,
    );
    controller.newChat();
    expect(controller.active.draft, isEmpty);
    expect(controller.active.attachments, isEmpty);
    expect(controller.active.role, AgentRole.assistant);
    controller.select(first);
    expect(controller.active.draft, 'My first draft');
    expect(controller.active.attachments, [file]);
    expect(controller.active.style, ReplyStyle.detailed);
    controller.removeAttachment(first, file.path);
    expect(controller.active.attachments, isEmpty);
  });

  test(
    'Empty sends are blocked, successful sends clear only the originating chat',
    () async {
      final responder = ControlledResponder();
      final controller = ChatController(responder: responder);
      addTearDown(controller.dispose);
      final first = controller.active.id;
      expect(await controller.send(first), isFalse);
      controller.updateDraft(first, 'Please help');
      final send = controller.send(first);
      expect(controller.active.sending, isTrue);
      expect(await controller.send(first), isFalse);
      expect(responder.calls, 1);
      controller.newChat();
      controller.updateDraft(controller.active.id, 'Another draft');
      responder.result.complete(
        ChatMessage(text: 'Demo answer', fromUser: false),
      );
      expect(await send, isTrue);
      expect(controller.active.draft, 'Another draft');
      expect(controller.active.messages, isEmpty);
      expect(controller.thread(first).draft, isEmpty);
      expect(controller.thread(first).messages.last.text, 'Demo answer');
    },
  );

  test('Failed submission preserves draft and attachment without duplicating history', () async {
    final responder = ControlledResponder();
    final controller = ChatController(responder: responder);
    addTearDown(controller.dispose);
    final id = controller.active.id;
    controller.updateDraft(id, 'Keep this text');
    controller.addAttachments(id, [
      const ChatAttachment(path: '/demo/a.txt', name: 'a.txt'),
    ]);
    final before = controller.active.messages.length;
    final send = controller.send(id);
    responder.result.completeError(StateError('Offline'));
    expect(await send, isFalse);
    expect(controller.active.draft, 'Keep this text');
    expect(controller.active.attachments.single.name, 'a.txt');
    expect(controller.active.messages.length, before);
    expect(controller.active.error, isNotNull);
    expect(controller.active.sending, isFalse);
  });

  test(
    'Demo configuration changes the demo output and files can be sent alone',
    () async {
      final controller = ChatController();
      addTearDown(controller.dispose);
      final id = controller.active.id;
      controller.configure(
        id,
        role: AgentRole.triage,
        style: ReplyStyle.detailed,
      );
      controller.addAttachments(id, [
        const ChatAttachment(path: '/demo/a.txt', name: 'a.txt'),
      ]);
      expect(await controller.send(id), isTrue);
      expect(controller.active.messages.last.text, contains('Demo triage'));
      expect(
        controller.active.messages.last.text,
        contains('No files were uploaded'),
      );
      expect(
        controller
            .active
            .messages[controller.active.messages.length - 2]
            .attachments
            .single
            .name,
        'a.txt',
      );
    },
  );
}
