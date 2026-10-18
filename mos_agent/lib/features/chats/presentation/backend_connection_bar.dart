import 'package:flutter/material.dart';

import '../application/chat_controller.dart';
import '../domain/inference_backend.dart';

class BackendConnectionBar extends StatelessWidget {
  const BackendConnectionBar({super.key, required this.controller});
  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.status;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(switch (status) {
                  BackendStatus.disconnected => 'Not connected',
                  BackendStatus.starting => 'Starting inference…',
                  BackendStatus.ready => 'Inference ready',
                  BackendStatus.failed => 'Connection failed',
                }, style: Theme.of(context).textTheme.labelLarge),
                Text(
                  'Messages sent to ${controller.destination}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (status != BackendStatus.ready)
                  OutlinedButton.icon(
                    onPressed: status == BackendStatus.starting
                        ? null
                        : controller.connect,
                    icon: const Icon(Icons.power_settings_new, size: 18),
                    label: const Text('Start inference'),
                  ),
                if (controller.creatingChat) const Text('Creating chat…'),
              ],
            ),
            if (status == BackendStatus.starting)
              const LinearProgressIndicator(),
            if (controller.connectionError != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  controller.connectionError!,
                  style: TextStyle(color: colors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
