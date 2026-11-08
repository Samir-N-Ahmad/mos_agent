import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_agent/app/help_desk_app.dart';
import 'package:mos_agent/integrations/window/desktop_window.dart';

class FakeDesktopWindow extends DesktopWindow {
  FakeDesktopWindow({this.isMacOS = false});
  @override
  final bool isMacOS;
  @override
  bool isMaximized = false;
  @override
  bool isFullScreen = false;
  final events = <String>[];
  @override
  void minimize() => events.add('minimize');
  @override
  void close() => events.add('close');
  @override
  void startDragging() => events.add('drag');
  @override
  void titleBarDoubleClick() => events.add('double-click');
  @override
  void toggleMaximize() {
    if (isFullScreen) {
      toggleFullScreen();
      return;
    }
    isMaximized = !isMaximized;
    events.add('maximize');
    notifyListeners();
  }

  @override
  void toggleFullScreen() {
    isFullScreen = !isFullScreen;
    events.add('fullscreen');
    notifyListeners();
  }
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    FakeDesktopWindow window, {
    bool compact = false,
  }) async {
    tester.view.physicalSize = compact
        ? const Size(480, 320)
        : const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(window.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('window-preview'),
        child: HelpDeskApp(demoMode: true, window: window),
      ),
    );
  }

  testWidgets('App window controls change state and preserve the draft', (
    tester,
  ) async {
    final window = FakeDesktopWindow();
    await mount(tester, window);
    final input = find.byKey(const ValueKey('message-input'));
    await tester.enterText(input, 'Keep this draft while maximizing');
    await tester.tap(find.byTooltip('Maximize window'));
    await tester.pump();
    expect(find.byTooltip('Restore window'), findsOneWidget);
    expect(
      tester.widget<TextField>(input).controller!.text,
      'Keep this draft while maximizing',
    );
    await tester.tap(find.byTooltip('Restore window'));
    await tester.pump();
    await tester.tap(find.byTooltip('Minimize window'));
    await tester.tap(find.byTooltip('Close window'));
    expect(window.events, ['maximize', 'maximize', 'minimize', 'close']);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_WINDOW')) {
      await tester.runAsync(() async {
        const fontDirectory = String.fromEnvironment('UI_FONT_DIR');
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
        final context = tester.element(
          find.byKey(const ValueKey('window-title-bar')),
        );
        for (final name in [
          'share',
          'plus',
          'settings',
          'bot',
          'shutdown',
          'wrench',
        ]) {
          await precacheImage(AssetImage('assets/icons/$name.png'), context);
        }
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('window-preview')),
        );
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/mos-frameless-preview.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets(
    'Dragging and double-clicking the title area dispatch window actions',
    (tester) async {
      final window = FakeDesktopWindow();
      await mount(tester, window);
      final area = find.byKey(const ValueKey('window-drag-area'));
      await tester.drag(area, const Offset(100, 20));
      expect(window.events, contains('drag'));
      await tester.tap(area);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(area);
      await tester.pumpAndSettle();
      expect(window.events, contains('double-click'));
    },
  );

  testWidgets(
    'Fullscreen shortcuts enter and exit without losing focus or text',
    (tester) async {
      final window = FakeDesktopWindow();
      await mount(tester, window);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.f11);
      await tester.pump();
      expect(window.isFullScreen, isTrue);
      expect(find.byTooltip('Exit fullscreen'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      final input = find.byKey(const ValueKey('message-input'));
      await tester.enterText(input, 'An unsent message');
      await tester.sendKeyEvent(LogicalKeyboardKey.f11);
      await tester.pump();
      expect(window.isFullScreen, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(window.isFullScreen, isFalse);
      expect(
        tester.widget<TextField>(input).controller!.text,
        'An unsent message',
      );
    },
  );

  testWidgets(
    'macOS controls sit on the left and support fullscreen in a small window',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final window = FakeDesktopWindow(isMacOS: true);
      await mount(tester, window, compact: true);
      expect(
        tester.getCenter(find.byTooltip('Close window')).dx,
        lessThan(tester.getCenter(find.byTooltip('Minimize window')).dx),
      );
      await tester.tap(find.byTooltip('Enter fullscreen'));
      await tester.pump();
      expect(window.isFullScreen, isTrue);
      expect(find.byTooltip('Exit fullscreen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
