import 'package:flutter/material.dart';

import '../features/chats/application/chat_controller.dart';
import '../features/chats/presentation/chats_workspace.dart';
import '../integrations/files/attachment_picker.dart';
import '../integrations/inference/http_inference_backend.dart';
import '../shared/widgets/workspace_sidebar.dart';
import 'workspace_section.dart';

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({
    super.key,
    this.demoMode = const bool.fromEnvironment('DEMO_MODE'),
  });
  final bool demoMode;

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  WorkspaceSection _section = WorkspaceSection.chats;
  late final _chats = widget.demoMode
      ? ChatController()
      : ChatController(
          backend: HttpInferenceBackend(
            destination: Uri.parse(
              const String.fromEnvironment(
                'INFERENCE_BASE_URL',
                defaultValue: 'http://127.0.0.1:8000',
              ),
            ),
          ),
        );
  final _attachmentPicker = NativeAttachmentPicker();

  @override
  void dispose() {
    _chats.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceSidebar(
            selectedSection: _section,
            onSelected: (section) => setState(() => _section = section),
          ),
          Expanded(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        _section.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _section == WorkspaceSection.chats ? 0 : 1,
                      children: [
                        ChatsWorkspace(
                          controller: _chats,
                          attachmentPicker: _attachmentPicker,
                        ),
                        _SectionContent(section: _section),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionContent extends StatelessWidget {
  const _SectionContent({required this.section});
  final WorkspaceSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        section.icon,
                        size: 28,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      section.emptyTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      section.description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Preview workspace · Integrations not connected',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
