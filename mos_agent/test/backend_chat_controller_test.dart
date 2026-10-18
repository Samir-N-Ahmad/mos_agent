import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mos_agent/features/chats/presentation/chats_workspace.dart';
import 'package:mos_agent/integrations/files/attachment_picker.dart';
import 'package:mos_agent/features/chats/application/chat_controller.dart';
import 'package:mos_agent/features/chats/domain/chat.dart';
import 'package:mos_agent/features/chats/domain/inference_backend.dart';

class FakeBackend implements InferenceBackend {
  final events = <String>[];
  final chunks = StreamController<String>();
  bool failStart = false;
  bool failNewChat = false;
  int nextId = 0;
  final modes = <ChatMode>[];
  List<ChatMode> availableModes = ChatMode.demoModes;
  bool failModes = false;
  @override
  Uri get destination => Uri.parse('http://127.0.0.1:8000');
  @override
  Future<void> start() async {
    events.add('start');
    if (failStart) {
      throw const InferenceFailure(
        InferenceFailureKind.connection,
        'Unavailable',
      );
    }
  }

  @override
  Future<List<ChatMode>> fetchModes() async {
    events.add('modes');
    if (failModes) {
      throw const InferenceFailure(
        InferenceFailureKind.protocol,
        'Invalid modes',
      );
    }
    return availableModes;
  }

  @override
  Future<String> newChat({required ChatMode mode}) async {
    events.add('new');
    modes.add(mode);
    if (failNewChat) {
      throw const InferenceFailure(
        InferenceFailureKind.server,
        'Could not create chat',
      );
    }
    return '${nextId++}';
  }

  @override
  Stream<String> send(String id, String message) {
    events.add('send:$id:$message');
    return chunks.stream;
  }

  @override
  void stopReceiving(String id) {
    events.add('stop:$id');
  }

  @override
  void close() {
    events.add('close');
    chunks.close();
  }
}

void main() {
  test('Connect starts inference then creates a server chat; duplicate connect is blocked', () async {
    final backend = FakeBackend();
    final controller = ChatController(backend: backend);
    addTearDown(controller.dispose);
    expect(controller.active.messages, isEmpty);
    expect(controller.isDemo, isFalse);
    final connection = controller.connect();
    await controller.connect();
    await connection;
    expect(backend.events, ['start', 'modes', 'new']);
    expect(controller.status, BackendStatus.ready);
    expect(controller.active.backendId, '0');
    await controller.newChat();
    expect(controller.active.backendId, '1');
  });

  test('Startup and new-chat failures are visible without fabricating a backend chat', () async {
    final backend = FakeBackend()..failStart = true;
    final controller = ChatController(backend: backend);
    addTearDown(controller.dispose);
    await controller.connect();
    expect(controller.status, BackendStatus.failed);
    expect(controller.active.backendId, isNull);
    expect(controller.connectionError, 'Unavailable');
    backend.failStart = false;
    await controller.connect();
    final count = controller.threads.length;
    backend.failNewChat = true;
    await controller.newChat();
    expect(controller.threads.length, count);
    expect(controller.connectionError, 'Could not create chat');
  });

  test(
    'Streamed deltas update original chat while another chat remains isolated',
    () async {
      final backend = FakeBackend();
      final controller = ChatController(backend: backend);
      addTearDown(controller.dispose);
      await controller.connect();
      final id = controller.active.id;
      controller.updateDraft(id, 'Help me');
      final pending = controller.send(id);
      expect(await controller.send(id), isFalse);
      backend.chunks.add('Hello');
      await Future<void>.delayed(Duration.zero);
      expect(controller.thread(id).messages.last.text, 'Hello');
      expect(
        controller.thread(id).messages.last.delivery,
        MessageDelivery.streaming,
      );
      expect(controller.thread(id).draft, 'Help me');
      await controller.newChat();
      controller.updateDraft(controller.active.id, 'Separate draft');
      backend.chunks.add(' there');
      await backend.chunks.close();
      expect(await pending, isTrue);
      expect(controller.active.draft, 'Separate draft');
      expect(controller.active.messages, isEmpty);
      expect(controller.thread(id).messages.last.text, 'Hello there');
      expect(
        controller.thread(id).messages.last.delivery,
        MessageDelivery.complete,
      );
      expect(controller.thread(id).draft, isEmpty);
      expect(backend.events.where((e) => e.startsWith('send:')), [
        'send:0:Help me',
      ]);
    },
  );

  test('Partial failures keep the answer marked incomplete and preserve drafts without replay', () async {
    final backend = FakeBackend();
    final controller = ChatController(backend: backend);
    addTearDown(controller.dispose);
    await controller.connect();
    final id = controller.active.id;
    controller.updateDraft(id, 'Keep this');
    final pending = controller.send(id);
    backend.chunks.add('Partial');
    backend.chunks.addError(
      const InferenceFailure(InferenceFailureKind.connection, 'Interrupted'),
    );
    expect(await pending, isFalse);
    expect(controller.active.messages.last.text, 'Partial');
    expect(
      controller.active.messages.last.delivery,
      MessageDelivery.interrupted,
    );
    expect(controller.active.draft, 'Keep this');
    expect(controller.active.sending, isFalse);
    expect(backend.events.where((e) => e.startsWith('send:')).length, 1);
  });

  test('Stopping reception ignores late chunks and never claims server cancellation', () async {
    final backend = FakeBackend();
    final controller = ChatController(backend: backend);
    addTearDown(controller.dispose);
    await controller.connect();
    final id = controller.active.id;
    controller.updateDraft(id, 'Hello');
    final pending = controller.send(id);
    backend.chunks.add('First');
    await Future<void>.delayed(Duration.zero);
    controller.stopReceiving(id);
    backend.chunks.add('Late data');
    await backend.chunks.close();
    expect(await pending, isFalse);
    expect(controller.active.messages.last.text, 'First');
    expect(controller.active.error, contains('Server generation may continue'));
    expect(controller.active.draft, 'Hello');
    expect(backend.events, contains('stop:0'));
  });

  test(
    'Disconnected sends and file attachments never reach the text-only API',
    () async {
      final backend = FakeBackend();
      final controller = ChatController(backend: backend);
      addTearDown(controller.dispose);
      final id = controller.active.id;
      controller.updateDraft(id, 'My text');
      expect(await controller.send(id), isFalse);
      expect(backend.events, isEmpty);
      await controller.connect();
      controller.addAttachments(id, [
        const ChatAttachment(path: '/demo/a.txt', name: 'a.txt'),
      ]);
      expect(await controller.send(id), isFalse);
      expect(controller.active.attachments.single.name, 'a.txt');
      expect(controller.active.draft, 'My text');
      expect(backend.events.where((e) => e.startsWith('send:')), isEmpty);
    },
  );

  testWidgets(
    'Backend UI starts inference and renders incremental answers without demo controls',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backend = FakeBackend();
      final controller = ChatController(backend: backend);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatsWorkspace(
              controller: controller,
              attachmentPicker: NativeAttachmentPicker(),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Messages sent to http://127.0.0.1:8000'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.arrow_upward),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Start inference'));
      await tester.pumpAndSettle();
      expect(find.text('Inference ready'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('message-input')),
        'Test message',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pump();
      backend.chunks.add('First chunk');
      await tester.pump();
      expect(find.text('First chunk'), findsOneWidget);
      expect(find.text('Agent'), findsOneWidget);
      expect(find.text('Agent · Demo'), findsNothing);
      expect(find.byTooltip('Stop receiving response'), findsOneWidget);
      backend.chunks.add(' and second');
      await backend.chunks.close();
      await tester.pumpAndSettle();
      expect(find.text('First chunk and second'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('message-input')))
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('New conversations send the selected mode and preserve it across draft updates and selection', () async {
    final backend = FakeBackend();
    final controller = ChatController(backend: backend);
    addTearDown(controller.dispose);
    await controller.connect();
    expect(controller.active.mode, ChatMode.chat);
    await controller.newChat(mode: ChatMode.classification);
    final classificationId = controller.active.id;
    expect(controller.active.mode, ChatMode.classification);
    controller.updateDraft(classificationId, 'The printer is broken.');
    final pending = controller.send(classificationId);
    backend.chunks.add('is');
    backend.chunks.add('sue');
    await backend.chunks.close();
    expect(await pending, isTrue);
    expect(controller.active.messages.last.text, 'issue');
    await controller.newChat();
    expect(controller.active.mode, ChatMode.chat);
    expect(backend.modes, [
      ChatMode.chat,
      ChatMode.classification,
      ChatMode.chat,
    ]);
    controller.select(classificationId);
    expect(controller.active.mode, ChatMode.classification);
    expect(controller.active.backendId, '1');
  });

  testWidgets(
    'Mode selector creates and labels a classification conversation',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backend = FakeBackend();
      final controller = ChatController(backend: backend);
      addTearDown(controller.dispose);
      await controller.connect();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatsWorkspace(
              controller: controller,
              attachmentPicker: NativeAttachmentPicker(),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('new-chat-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Classification').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New chat').first);
      await tester.pumpAndSettle();
      expect(controller.active.mode, ChatMode.classification);
      expect(backend.modes, [ChatMode.chat, ChatMode.classification]);
      expect(find.text('Classification mode'), findsOneWidget);
    },
  );

  test('Server catalogue determines the default and allows modes beyond the original pair', () async {
    const chat = ChatMode(name: 'CHAT', value: '42');
    const extra = ChatMode(name: 'SUMMARIZE', value: '7');
    final backend = FakeBackend()..availableModes = [extra, chat];
    final controller = ChatController(backend: backend);
    addTearDown(controller.dispose);
    await controller.connect();
    expect(controller.modes, [extra, chat]);
    expect(controller.active.mode.value, '42');
    expect(controller.active.mode.name, 'CHAT');
    await controller.newChat(mode: extra);
    expect(controller.active.mode, extra);
    expect(backend.modes, [chat, extra]);
    final count = controller.threads.length;
    await controller.newChat(
      mode: const ChatMode(name: 'Unknown', value: '99'),
    );
    expect(controller.threads.length, count);
    expect(backend.modes, [chat, extra]);
    expect(controller.connectionError, contains('available backend mode'));
  });

  test('Mode discovery failure preserves drafts and never creates a chat with fallback values', () async {
    final backend = FakeBackend()..failModes = true;
    final controller = ChatController(backend: backend);
    addTearDown(controller.dispose);
    final id = controller.active.id;
    controller.updateDraft(id, 'Keep this draft');
    expect(controller.modes, isEmpty);
    await controller.connect();
    expect(controller.status, BackendStatus.failed);
    expect(controller.active.backendId, isNull);
    expect(controller.active.draft, 'Keep this draft');
    expect(backend.modes, isEmpty);
    backend.failModes = false;
    backend.availableModes = [];
    await controller.connect();
    expect(controller.status, BackendStatus.failed);
    expect(backend.modes, isEmpty);
  });

  testWidgets('Selector shows only server-discovered mode names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const extra = ChatMode(name: 'SUMMARIZE', value: '7');
    final backend = FakeBackend()..availableModes = [extra];
    final controller = ChatController(backend: backend);
    addTearDown(controller.dispose);
    await controller.connect();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatsWorkspace(
            controller: controller,
            attachmentPicker: NativeAttachmentPicker(),
          ),
        ),
      ),
    );
    final selector = tester.widget<DropdownButton<ChatMode>>(
      find.byKey(const ValueKey('new-chat-mode')),
    );
    expect(selector.items!.map((item) => item.value!.name), ['SUMMARIZE']);
    expect(selector.value, extra);
    await tester.tap(find.text('New chat').first);
    await tester.pumpAndSettle();
    expect(controller.active.mode, extra);
    expect(backend.modes, [extra, extra]);
  });
}
