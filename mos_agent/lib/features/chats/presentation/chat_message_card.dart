import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/app_icon.dart';
import '../domain/chat.dart';

class ChatMessageCard extends StatelessWidget {
  const ChatMessageCard({
    super.key,
    required this.message,
    this.demoMode = false,
  });
  final ChatMessage message;
  final bool demoMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 960),
        margin: const EdgeInsets.only(bottom: 36),
        padding: message.fromUser
            ? const EdgeInsets.symmetric(horizontal: 22, vertical: 16)
            : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: message.fromUser
              ? colors.surfaceContainerHighest
              : colors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.fromUser) ...[
              Row(
                children: [
                  const AppIcon(AppIconType.bot, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      demoMode ? 'MOS Agent · Demo' : 'MOS Agent',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            if (message.delivery != MessageDelivery.complete)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(switch (message.delivery) {
                  MessageDelivery.streaming => 'Responding…',
                  MessageDelivery.cancelled => 'Cancelled response',
                  _ => 'Incomplete response',
                }, style: theme.textTheme.labelMedium),
              ),
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: message.fromUser
                      ? colors.onSurface
                      : colors.onSurfaceVariant,
                ),
              ),
            for (final file in message.attachments)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '📎 ${file.name}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            if (!message.fromUser && message.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: IconButton(
                  tooltip: 'Copy response',
                  icon: const AppIcon(AppIconType.share, size: 20),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: message.text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Response copied')),
                      );
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
