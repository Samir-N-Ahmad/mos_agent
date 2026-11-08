import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart' as native;

import '../../core/diagnostics/app_log.dart';

/// The app-facing window contract. Widget tests inject a fake implementation.
abstract class DesktopWindow extends ChangeNotifier {
  bool get isMacOS;
  bool get isMaximized;
  bool get isFullScreen;
  void minimize();
  void toggleMaximize();
  void toggleFullScreen();
  void close();
  void startDragging();
  void titleBarDoubleClick();
}

class NativeDesktopWindow extends DesktopWindow {
  NativeDesktopWindow._(this._window) {
    _listener = _window.addListener((event) {
      if (event is native.WindowMaximizedEvent ||
          event is native.WindowRestoredEvent ||
          event is native.WindowEnteredFullScreenEvent ||
          event is native.WindowExitedFullScreenEvent) {
        notifyListeners();
      }
    });
  }

  final native.Window _window;
  late final native.ListenerId _listener;

  /// Called after Flutter binding initialization; other targets keep native chrome.
  static NativeDesktopWindow? initialize() {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.macOS &&
            defaultTargetPlatform != TargetPlatform.windows)) {
      return null;
    }
    final window = native.WindowManager.instance.getCurrent();
    if (window == null) {
      AppLog.instance.add(
        'Window',
        'No desktop window available; keeping the system frame.',
      );
      return null;
    }
    try {
      window.title = 'MOS Agent';
      window.minimumSize = native.SizeToNative(const Size(480, 320)).toNative();
      window.isResizable = true;
      if (!window.setFrameless(true)) {
        window.setFrameless(false);
        window.dispose();
        AppLog.instance.add(
          'Window',
          'Frameless mode unavailable; keeping the system frame.',
        );
        return null;
      }
      final controller = NativeDesktopWindow._(window);
      AppLog.instance.add('Window', 'Frameless desktop window ready');
      return controller;
    } catch (_) {
      // Do not leave a window without usable controls if initialization fails.
      window.setFrameless(false);
      window.dispose();
      rethrow;
    }
  }

  @override
  bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;
  @override
  bool get isMaximized => _window.isMaximized;
  @override
  bool get isFullScreen => _window.isFullScreen;
  @override
  void minimize() => _window.minimize();
  @override
  void toggleMaximize() {
    if (isFullScreen) {
      toggleFullScreen();
    } else if (isMaximized) {
      _window.unmaximize();
    } else {
      _window.maximize();
    }
  }

  @override
  void toggleFullScreen() => _window.isFullScreen = !isFullScreen;
  @override
  void close() => _window.close();
  @override
  void startDragging() => _window.startDragging();
  @override
  void titleBarDoubleClick() => _window.performTitleBarDoubleClick();

  @override
  void dispose() {
    _window.removeListener(_listener);
    _window.dispose();
    super.dispose();
  }
}

/// Native hit regions live outside the chat UI. Resize handles disappear when
/// maximized/fullscreen and never cover the inset title-bar buttons.
class DesktopResizeArea extends StatelessWidget {
  const DesktopResizeArea({
    super.key,
    required this.window,
    required this.child,
  });
  final DesktopWindow window;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (window is! NativeDesktopWindow) return child;
    final adapter = window as NativeDesktopWindow;
    return ListenableBuilder(
      listenable: window,
      builder: (context, _) => native.DragToResizeArea(
        window: adapter._window,
        resizeEdgeSize: 5,
        enableResizeEdges: window.isMaximized || window.isFullScreen
            ? const []
            : null,
        child: child,
      ),
    );
  }
}

/// Windows 11 native maximize hit testing enables its Snap Layouts menu.
class DesktopMaximizeArea extends StatelessWidget {
  const DesktopMaximizeArea({
    super.key,
    required this.window,
    required this.child,
  });
  final DesktopWindow window;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      window is NativeDesktopWindow && !window.isMacOS
      ? native.MaximizeButtonArea(
          window: (window as NativeDesktopWindow)._window,
          child: child,
        )
      : child;
}
