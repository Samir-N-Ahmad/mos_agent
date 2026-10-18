import 'package:flutter/material.dart';

import '../domain/chat.dart';

class ChatConfiguration {
  const ChatConfiguration(this.role, this.style);
  final AgentRole role;
  final ReplyStyle style;
}

Future<ChatConfiguration?> showChatConfiguration(
  BuildContext context,
  ChatThread thread,
) {
  return showDialog<ChatConfiguration>(
    context: context,
    builder: (context) {
      var role = thread.role;
      var style = thread.style;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Chat configuration'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Local demo · No AI model connected'),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<AgentRole>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'Agent role',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: AgentRole.values
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(switch (v) {
                              AgentRole.assistant => 'Assistant',
                              AgentRole.triage => 'Triage',
                              AgentRole.reply => 'Reply drafting',
                            }, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => role = v);
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<ReplyStyle>(
                    initialValue: style,
                    decoration: const InputDecoration(
                      labelText: 'Response style',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: ReplyStyle.values
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(
                              v == ReplyStyle.concise ? 'Concise' : 'Detailed',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => style = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'These choices change the demo response only. Messages and file references remain in this app session.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, ChatConfiguration(role, style)),
              child: const Text('Save'),
            ),
          ],
        ),
      );
    },
  );
}
