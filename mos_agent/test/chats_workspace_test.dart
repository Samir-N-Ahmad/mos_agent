import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_agent/core/theme/app_theme.dart';
import 'package:mos_agent/app/help_desk_app.dart';
import 'package:mos_agent/features/chats/application/chat_controller.dart';
import 'package:mos_agent/features/chats/domain/chat.dart';
import 'package:mos_agent/features/chats/presentation/chats_workspace.dart';
import 'package:mos_agent/integrations/files/attachment_picker.dart';

class FakePicker implements AttachmentPicker {
  List<ChatAttachment> files = [];
  bool fail = false;
  Completer<List<ChatAttachment>>? pending;
  @override
  Future<List<ChatAttachment>> pick() async {
    if (fail) throw StateError('Unavailable');
    if (pending != null) return pending!.future;
    return files;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const fontDirectory = String.fromEnvironment('UI_FONT_DIR');
    if (const bool.fromEnvironment('CAPTURE_UI') && fontDirectory.isNotEmpty) {
      for (final font in {
        'Roboto': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final loader = FontLoader(font.key);
        loader.addFont(
          File('$fontDirectory/${font.value}')
              .readAsBytes()
              .then(ByteData.sublistView),
        );
        await loader.load();
      }
    }
  });
  late ChatController controller;
  late FakePicker picker;
  final input = find.byKey(const ValueKey('message-input'));

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('chat-preview'),
            child: ChatsWorkspace(
              controller: controller,
              attachmentPicker: picker,
            ),
          ),
        ),
      ),
    );
  }

  setUp(() {
    controller = ChatController();
    picker = FakePicker();
  });
  tearDown(() => controller.dispose());

  testWidgets('Chat list starts at 20 percent and both resize handles work', (
    tester,
  ) async {
    await mount(tester);
    expect(
      tester.getSize(find.byKey(const ValueKey('chat-list-pane'))).width,
      256,
    );
    await tester.drag(
      find.byKey(const ValueKey('chat-list-resize')),
      const Offset(100, 0),
    );
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const ValueKey('chat-list-pane'))).width,
      greaterThan(256),
    );
    final area = find.byKey(const ValueKey('message-input-area'));
    expect(tester.getSize(area).height, 100);
    await tester.drag(
      find.byKey(const ValueKey('composer-resize')),
      const Offset(0, -70),
    );
    await tester.pump();
    expect(tester.getSize(area).height, greaterThan(100));
    await tester.drag(
      find.byKey(const ValueKey('composer-resize')),
      const Offset(0, 300),
    );
    await tester.pump();
    expect(tester.getSize(area).height, 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Enter sends, Shift+Enter adds a newline, composition does not send',
    (tester) async {
      await mount(tester);
      await tester.enterText(input, 'First line');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(controller.active.draft, 'First line\n');
      expect(controller.active.messages.length, 1);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'مرحبا',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 0, end: 5),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(controller.active.messages.length, 1);
      await tester.enterText(input, 'Ready to send');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(controller.active.messages.length, 3);
      expect(controller.active.messages[1].text, 'Ready to send');
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      final send = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_upward),
      );
      expect(send.onPressed, isNull);
    },
  );

  testWidgets(
    'Draft survives chat switching and files can be attached and removed',
    (tester) async {
      await mount(tester);
      await tester.enterText(input, 'Unsaved thought');
      await tester.tap(find.byKey(const ValueKey('select-draft')));
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      await tester.tap(find.byKey(const ValueKey('select-welcome')));
      await tester.pump();
      expect(
        tester.widget<TextField>(input).controller!.text,
        'Unsaved thought',
      );
      picker.files = [
        const ChatAttachment(path: '/demo/report.pdf', name: 'report.pdf'),
      ];
      await tester.tap(find.byTooltip('Attach files'));
      await tester.pumpAndSettle();
      expect(find.text('report.pdf'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove report.pdf'));
      await tester.pump();
      expect(controller.active.attachments, isEmpty);
      picker.files = [];
      await tester.tap(find.byTooltip('Attach files'));
      await tester.pumpAndSettle();
      expect(controller.active.draft, 'Unsaved thought');
      picker.fail = true;
      await tester.tap(find.byTooltip('Attach files'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not open the file picker'),
        findsOneWidget,
      );
      expect(controller.active.draft, 'Unsaved thought');
    },
  );

  testWidgets('Picking files remains bound to the originating chat', (
    tester,
  ) async {
    await mount(tester);
    picker.pending = Completer<List<ChatAttachment>>();
    await tester.tap(find.byTooltip('Attach files'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('select-draft')));
    await tester.pump();
    picker.pending!.complete([
      const ChatAttachment(path: '/demo/a.txt', name: 'a.txt'),
    ]);
    await tester.pumpAndSettle();
    expect(controller.active.attachments, isEmpty);
    expect(controller.thread('welcome').attachments.single.name, 'a.txt');
  });

  testWidgets('Configuration saves per chat and new chat starts empty', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byTooltip('Agent and chat configuration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Detailed').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(controller.active.style, ReplyStyle.detailed);
    await tester.tap(find.text('New chat'));
    await tester.pump();
    expect(controller.active.messages, isEmpty);
    expect(controller.active.style, ReplyStyle.concise);
    expect(find.textContaining('How can I help?'), findsOneWidget);
  });

  testWidgets(
    'Compact layout exposes a chat picker and controls at enlarged text',
    (tester) async {
      await mount(tester, size: const Size(480, 320), scale: 2);
      expect(find.byKey(const ValueKey('chat-list-pane')), findsNothing);
      await tester.tap(find.byTooltip('Choose chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('new-chat-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Classification').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<ChatMode>>(
              find.byKey(const ValueKey('new-chat-mode')),
            )
            .value,
        ChatMode.classification,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('select-draft')),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('select-draft')));
      await tester.pumpAndSettle();
      expect(controller.active.id, 'draft');
      await tester.ensureVisible(input);
      await tester.enterText(input, 'A compact-window message');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(
        controller.active.messages.last.text,
        contains('Demo assistant response'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Desktop conversation preview', (tester) async {
    await mount(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('chat-preview'),
        child: const HelpDeskApp(),
      ),
    );
    await tester.enterText(
      input,
      'Summarize the issue and suggest the next steps.',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('chat-preview')),
        );
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/mos-agent-chats.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
