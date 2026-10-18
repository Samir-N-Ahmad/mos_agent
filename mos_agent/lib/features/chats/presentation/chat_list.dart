import 'package:flutter/material.dart';

import '../domain/chat.dart';

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
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Tooltip(
              message: 'Mode for new chats',
              child: DropdownButton<ChatMode>(
                key: const ValueKey('new-chat-mode'),
                value: newChatMode,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                hint: const Text(
                  'Start inference to load modes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: canCreate ? onNewChat : null,
                icon: const Icon(Icons.edit_square, size: 18),
                label: const Text(
                  'New chat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: threads.length,
              itemBuilder: (context, index) {
                final thread = threads[index];
                final selected = thread.id == selectedId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    key: ValueKey('select-${thread.id}'),
                    selected: selected,
                    selectedTileColor: theme.colorScheme.secondaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(
                      thread.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${thread.mode.label} · ${thread.sending
                          ? 'Responding…'
                          : thread.draft.isNotEmpty
                          ? 'Draft'
                          : demoMode
                          ? 'Demo'
                          : thread.backendId ?? 'Not connected'}',
                      maxLines: 1,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    onTap: () => onSelected(thread.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
