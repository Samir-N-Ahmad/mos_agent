import 'package:flutter/material.dart';

import '../domain/chat.dart';

class ChatConversation extends StatefulWidget {
  const ChatConversation({
    super.key,
    required this.thread,
    this.demoMode = true,
  });
  final ChatThread thread;
  final bool demoMode;

  @override
  State<ChatConversation> createState() => _ChatConversationState();
}

class _ChatConversationState extends State<ChatConversation> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant ChatConversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.thread.messages.length != widget.thread.messages.length ||
        (widget.thread.messages.isNotEmpty &&
            oldWidget.thread.messages.isNotEmpty &&
            widget.thread.messages.last.text !=
                oldWidget.thread.messages.last.text);
    final nearBottom =
        !_scroll.hasClients || _scroll.position.extentAfter < 100;
    if (changed && nearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (widget.thread.messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'How can I help?\nStart a conversation with your agent.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SelectionArea(
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        itemCount: widget.thread.messages.length,
        itemBuilder: (context, index) {
          final message = widget.thread.messages[index];
          return Align(
            alignment: message.fromUser
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 760),
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: message.fromUser
                    ? colors.surfaceContainerHigh
                    : colors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fromUser
                        ? 'You'
                        : widget.demoMode
                        ? 'Agent · Demo'
                        : 'Agent',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  if (message.delivery != MessageDelivery.complete)
                    Text(
                      message.delivery == MessageDelivery.streaming
                          ? 'Responding…'
                          : 'Incomplete response',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(height: 1.6),
                    ),
                  for (final file in message.attachments)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '📎 ${file.name}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
