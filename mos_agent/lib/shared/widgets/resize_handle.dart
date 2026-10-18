import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pointer and keyboard access to a split pane or composer size.
class ResizeHandle extends StatelessWidget {
  const ResizeHandle({
    super.key,
    required this.axis,
    required this.label,
    required this.onDelta,
  });
  final Axis axis;
  final String label;
  final ValueChanged<double> onDelta;

  @override
  Widget build(BuildContext context) {
    final vertical = axis == Axis.vertical;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      onIncrease: () => onDelta(vertical ? -16 : 16),
      onDecrease: () => onDelta(vertical ? 16 : -16),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          final decrease = vertical
              ? LogicalKeyboardKey.arrowUp
              : LogicalKeyboardKey.arrowLeft;
          final increase = vertical
              ? LogicalKeyboardKey.arrowDown
              : LogicalKeyboardKey.arrowRight;
          if (event.logicalKey == decrease || event.logicalKey == increase) {
            onDelta(event.logicalKey == decrease ? -16 : 16);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return Tooltip(
              message: '$label · Drag or use arrow keys when focused',
              child: MouseRegion(
                cursor: vertical
                    ? SystemMouseCursors.resizeUpDown
                    : SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: vertical
                      ? (d) => onDelta(d.delta.dy)
                      : null,
                  onHorizontalDragUpdate: vertical
                      ? null
                      : (d) => onDelta(d.delta.dx),
                  child: Container(
                    width: vertical ? double.infinity : 8,
                    height: vertical ? 14 : double.infinity,
                    color: focused
                        ? colors.primaryContainer
                        : colors.surfaceContainerLow,
                    alignment: Alignment.center,
                    child: Container(
                      width: vertical ? 32 : 2,
                      height: vertical ? 3 : 32,
                      decoration: BoxDecoration(
                        color: focused ? colors.primary : colors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
