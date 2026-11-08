import 'package:flutter/material.dart';

import 'app_icon.dart';

/// Persistent account actions below the scrolling history, matching the design.
/// No account name is invented while authentication is unavailable.
class HistoryAccountFooter extends StatelessWidget {
  const HistoryAccountFooter({
    super.key,
    required this.onProfile,
    required this.onSettings,
  });
  final VoidCallback onProfile;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      key: const ValueKey('history-account-footer'),
      padding: const EdgeInsets.fromLTRB(10, 12, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: 'Profile',
              child: OutlinedButton(
                onPressed: onProfile,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.onSurface,
                  side: BorderSide(color: colors.outlineVariant),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colors.secondaryContainer,
                      child: Icon(
                        Icons.person_outline,
                        color: colors.onSurface,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Profile',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Not signed in',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: const AppIcon(AppIconType.settings, size: 24),
          ),
        ],
      ),
    );
  }
}
