import 'package:flutter/material.dart';

import '../../app/workspace_section.dart';

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    super.key,
    required this.selectedSection,
    required this.onSelected,
  });

  final WorkspaceSection selectedSection;
  final ValueChanged<WorkspaceSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 60,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border(right: BorderSide(color: colors.outlineVariant)),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          for (final section in WorkspaceSection.values)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Semantics(
                                selected: section == selectedSection,
                                child: IconButton(
                                  tooltip: section.title,
                                  isSelected: section == selectedSection,
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(44, 44),
                                    foregroundColor: colors.onSurfaceVariant,
                                    backgroundColor: section == selectedSection
                                        ? colors.secondaryContainer
                                        : Colors.transparent,
                                    focusColor: colors.primary.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                  selectedIcon: Icon(
                                    section.selectedIcon,
                                    color: colors.onSecondaryContainer,
                                  ),
                                  icon: Icon(section.icon),
                                  onPressed: () => onSelected(section),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const IconButton(
                        tooltip: 'Logout — sign-in is not connected',
                        onPressed: null,
                        icon: Icon(Icons.logout),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
