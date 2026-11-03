import 'package:flutter/material.dart';

import '../../../shared/widgets/app_icon.dart';
import '../application/chat_controller.dart';
import '../domain/inference_backend.dart';

/// Compact inference control; details are available through its tooltip.
class BackendConnectionBar extends StatelessWidget {
  const BackendConnectionBar({super.key, required this.controller});
  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    final starting = controller.status == BackendStatus.starting;
    final ready = controller.status == BackendStatus.ready;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (starting)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: 'Starting inference',
              ),
            ),
          ),
        IconButton(
          tooltip: controller.isDemo
              ? 'Local demo — no inference service'
              : ready
              ? 'Inference ready · ${controller.destination}'
              : 'Start inference · ${controller.destination}',
          onPressed: controller.isDemo || starting || ready
              ? null
              : controller.connect,
          icon: AppIcon(
            AppIconType.shutdown,
            size: 24,
            color: ready ? Theme.of(context).colorScheme.onSurface : null,
          ),
        ),
      ],
    );
  }
}
