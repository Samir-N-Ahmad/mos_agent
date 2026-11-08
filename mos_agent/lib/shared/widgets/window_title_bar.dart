import 'package:flutter/material.dart';

import '../../integrations/window/desktop_window.dart';

/// App-drawn controls share the workspace surface instead of a system title bar.
class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({super.key, required this.window});
  final DesktopWindow window;

  Widget _button(
    BuildContext context,
    String tooltip,
    IconData icon,
    VoidCallback action,
  ) => IconButton(
    tooltip: tooltip,
    onPressed: action,
    iconSize: 16,
    style: IconButton.styleFrom(
      minimumSize: const Size(40, 40),
      maximumSize: const Size(40, 40),
      padding: EdgeInsets.zero,
      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    icon: Icon(icon),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: window,
    builder: (context, _) {
      final expandLabel = window.isFullScreen
          ? 'Exit fullscreen'
          : window.isMacOS
          ? 'Enter fullscreen'
          : window.isMaximized
          ? 'Restore window'
          : 'Maximize window';
      final expandIcon = window.isFullScreen
          ? Icons.fullscreen_exit
          : window.isMacOS
          ? Icons.fullscreen
          : window.isMaximized
          ? Icons.filter_none
          : Icons.crop_square;
      final controls = [
        _button(context, 'Minimize window', Icons.remove, window.minimize),
        DesktopMaximizeArea(
          window: window,
          child: _button(
            context,
            expandLabel,
            expandIcon,
            window.isMacOS ? window.toggleFullScreen : window.toggleMaximize,
          ),
        ),
      ];
      final close = _button(context, 'Close window', Icons.close, window.close);
      return SizedBox(
        key: const ValueKey('window-title-bar'),
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              if (window.isMacOS) ...[close, ...controls],
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('window-drag-area'),
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => window.startDragging(),
                  onDoubleTap: window.titleBarDoubleClick,
                  child: Align(
                    alignment: window.isMacOS
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'MOS Agent',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                ),
              ),
              if (!window.isMacOS) ...[...controls, close],
            ],
          ),
        ),
      );
    },
  );
}
