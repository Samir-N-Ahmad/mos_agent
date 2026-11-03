import 'package:flutter/material.dart';

import '../domain/chat.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/sidebar_item.dart';

class ChatList extends StatelessWidget {
  const ChatList({
    super.key,
    required this.threads,
    required this.selectedId,
    required this.onSelected,
    required this.onNewChat,
    this.canCreate = true,
    this.demoMode = true,
    required this.newChatMode,
    required this.modes,
    required this.onModeChanged,
  });
  final List<ChatThread> threads;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onNewChat;
  final bool canCreate;
  final bool demoMode;
  final ChatMode? newChatMode;
  final List<ChatMode> modes;
  final ValueChanged<ChatMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 4, 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 10, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Chat History',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'New chat',
                          onPressed: canCreate ? onNewChat : null,
                          icon: const AppIcon(AppIconType.plus, size: 26),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Tooltip(
                      message: 'Mode for new chats',
                      child: DropdownButton<ChatMode>(
                        key: const ValueKey('new-chat-mode'),
                        value: newChatMode,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        style: theme.textTheme.labelLarge,
                        hint: Text(
                          'Connect to load modes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        items: modes
                            .map(
                              (mode) => DropdownMenuItem(
                                value: mode,
                                child: Text(
                                  mode.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: canCreate
                            ? (mode) {
                                if (mode != null) onModeChanged(mode);
                              }
                            : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                    child: Text(
                      'This session',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverList.builder(
                itemCount: threads.length,
                itemBuilder: (context, index) {
                  final thread = threads[index];
                  final state = thread.cancelling
                      ? 'Cancelling…'
                      : thread.sending
                      ? 'Responding…'
                      : thread.draft.isNotEmpty
                      ? 'Draft · '
                      : '';
                  final preview =
                      thread.messages.lastOrNull?.text ??
                      'Start a new conversation';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SidebarItem(
                      key: ValueKey('select-${thread.id}'),
                      title: thread.title,
                      preview: '$state$preview',
                      selected: thread.id == selectedId,
                      onTap: () => onSelected(thread.id),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  demoMode
                      ? 'Local demo · This session only'
                      : 'This session only',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
