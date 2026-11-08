import 'package:flutter/material.dart';

import '../features/chats/application/chat_controller.dart';
import '../features/chats/presentation/chats_workspace.dart';
import '../integrations/files/attachment_picker.dart';
import '../integrations/inference/http_inference_backend.dart';
import '../shared/widgets/window_title_bar.dart';
import '../shared/widgets/desktop_window_frame.dart';
import '../integrations/window/desktop_window.dart';

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({
    super.key,
    this.window,
    this.demoMode = const bool.fromEnvironment('DEMO_MODE'),
  });
  final bool demoMode;
  final DesktopWindow? window;

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
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
    final workspace = Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.window != null) WindowTitleBar(window: widget.window!),
            Expanded(
              child: ChatsWorkspace(
                controller: _chats,
                attachmentPicker: _attachmentPicker,
              ),
            ),
          ],
        ),
      ),
    );
    return widget.window == null
        ? workspace
        : DesktopWindowFrame(window: widget.window!, child: workspace);
  }
}
