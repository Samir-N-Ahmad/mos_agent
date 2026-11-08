import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../integrations/window/desktop_window.dart';

class DesktopWindowFrame extends StatelessWidget {
  const DesktopWindowFrame({
    super.key,
    required this.window,
    required this.child,
  });
  final DesktopWindow window;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: window,
    builder: (context, _) => CallbackShortcuts(
      bindings: {
        if (window.isMacOS)
          const SingleActivator(
            LogicalKeyboardKey.keyF,
            control: true,
            meta: true,
          ): window.toggleFullScreen,
        if (!window.isMacOS)
          const SingleActivator(LogicalKeyboardKey.f11):
              window.toggleFullScreen,
        if (window.isFullScreen)
          const SingleActivator(LogicalKeyboardKey.escape):
              window.toggleFullScreen,
      },
      child: Focus(
        autofocus: true,
        child: DesktopResizeArea(window: window, child: child),
      ),
    ),
  );
}
