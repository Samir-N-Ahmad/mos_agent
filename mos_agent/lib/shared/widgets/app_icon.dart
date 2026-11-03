import 'package:flutter/material.dart';

enum AppIconType { share, plus, settings, bot, shutdown, wrench }

/// Supplied monochrome artwork follows the current semantic icon color.
class AppIcon extends StatelessWidget {
  const AppIcon(this.type, {super.key, this.size = 22, this.color});
  final AppIconType type;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/icons/${type.name}.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    color: color ?? IconTheme.of(context).color,
    excludeFromSemantics: true,
    filterQuality: FilterQuality.high,
  );
}
