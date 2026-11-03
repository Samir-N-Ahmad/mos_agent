import 'package:flutter/material.dart';

import '../domain/chat.dart';
import '../../../shared/widgets/app_icon.dart';
import 'chat_message_card.dart';

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
    if (widget.thread.messages.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(AppIconType.bot, size: 48),
                const SizedBox(height: 24),
                Text(
                  'How can I help?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Start a conversation with MOS Agent.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SelectionArea(
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        itemCount: widget.thread.messages.length,
        itemBuilder: (context, index) => ChatMessageCard(
          message: widget.thread.messages[index],
          demoMode: widget.demoMode,
        ),
      ),
    );
  }
}
