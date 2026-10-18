import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../integrations/files/attachment_picker.dart';
import '../../../shared/widgets/resize_handle.dart';
import '../application/chat_controller.dart';
import '../domain/inference_backend.dart';
import '../domain/chat.dart';
import 'backend_connection_bar.dart';
import 'chat_composer.dart';
import 'chat_configuration.dart';
import 'chat_conversation.dart';
import 'chat_list.dart';

class ChatsWorkspace extends StatefulWidget {
  const ChatsWorkspace({
    super.key,
    required this.controller,
    required this.attachmentPicker,
  });
  final ChatController controller;
  final AttachmentPicker attachmentPicker;

  @override
  State<ChatsWorkspace> createState() => _ChatsWorkspaceState();
}

class _ChatsWorkspaceState extends State<ChatsWorkspace> {
  double _listFraction = 0.2;
  ChatMode? _newChatMode;
  bool _picking = false;
  String? _attachmentError;

  Future<void> _attach() async {
    final id = widget.controller.active.id;
    setState(() {
      _picking = true;
      _attachmentError = null;
    });
    try {
      final files = await widget.attachmentPicker.pick();
      if (mounted) widget.controller.addAttachments(id, files);
    } catch (_) {
      if (mounted) {
        setState(
          () => _attachmentError = 'Could not open the file picker. Your draft is preserved; try attaching again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _configure() async {
    final thread = widget.controller.active;
    if (!widget.controller.isDemo) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backend configuration'),
          content: SingleChildScrollView(
            child: Text(
              'Service: ${widget.controller.destination}\n\nThis conversation uses ${thread.mode.label.toLowerCase()} mode. Select a mode before creating a new chat to use a different mode.\n\nAgent role and response style are controlled by the inference service. This API does not expose chat configuration or file uploads.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    final result = await showChatConfiguration(context, thread);
    if (result != null && mounted) {
      widget.controller.configure(
        thread.id,
        style: result.style,
        role: result.role,
      );
    }
  }

  Widget _list({VoidCallback? onDone, VoidCallback? onModeUpdated}) {
    final modes = widget.controller.modes;
    final selected =
        modes.where((mode) => mode == _newChatMode).firstOrNull ??
        widget.controller.defaultMode;
    return ChatList(
      threads: widget.controller.threads,
      selectedId: widget.controller.active.id,
      demoMode: widget.controller.isDemo,
      modes: modes,
      newChatMode: selected,
      onModeChanged: (mode) {
        setState(() => _newChatMode = mode);
        onModeUpdated?.call();
      },
      canCreate:
          selected != null &&
          !widget.controller.creatingChat &&
          (widget.controller.isDemo ||
              widget.controller.status == BackendStatus.ready),
      onSelected: (id) {
        widget.controller.select(id);
        onDone?.call();
      },
      onNewChat: () {
        widget.controller.newChat(mode: selected);
        onDone?.call();
      },
    );
  }

  void _showChats() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: StatefulBuilder(
            builder: (context, refreshSheet) => ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) => _list(
                onDone: () => Navigator.pop(context),
                onModeUpdated: () => refreshSheet(() {}),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final width = constraints.maxWidth * _listFraction;
        return Column(
          children: [
            if (!widget.controller.isDemo)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.4,
                ),
                child: SingleChildScrollView(
                  child: BackendConnectionBar(controller: widget.controller),
                ),
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!compact) ...[
                    SizedBox(
                      key: const ValueKey('chat-list-pane'),
                      width: width,
                      child: _list(),
                    ),
                    ResizeHandle(
                      key: const ValueKey('chat-list-resize'),
                      axis: Axis.horizontal,
                      label: 'Resize chat list',
                      onDelta: (delta) => setState(
                        () => _listFraction =
                            (_listFraction + delta / constraints.maxWidth)
                                .clamp(0.16, 0.45),
                      ),
                    ),
                  ],
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, chatConstraints) {
                        final thread = widget.controller.active;
                        final content = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                              child: Row(
                                children: [
                                  if (compact)
                                    IconButton(
                                      tooltip: 'Choose chat',
                                      onPressed: _showChats,
                                      icon: const Icon(Icons.menu),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          thread.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        Text(
                                          '${thread.mode.label} mode',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Tooltip(
                                    message: widget.controller.isDemo
                                        ? 'No model connected'
                                        : widget.controller.status ==
                                              BackendStatus.ready
                                        ? 'Inference service ready'
                                        : 'Start inference to connect',
                                    child: Icon(
                                      widget.controller.isDemo ||
                                              widget.controller.status !=
                                                  BackendStatus.ready
                                          ? Icons.cloud_off_outlined
                                          : Icons.check_circle_outline,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ChatConversation(
                                key: ValueKey('conversation-${thread.id}'),
                                thread: thread,
                                demoMode: widget.controller.isDemo,
                              ),
                            ),
                            if (thread.error != null ||
                                _attachmentError != null)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    thread.error ?? _attachmentError!,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ),
                              ),
                            ChatComposer(
                              key: ValueKey('composer-${thread.id}'),
                              thread: thread,
                              pickingFiles: _picking,
                              demoMode: widget.controller.isDemo,
                              sendingAllowed:
                                  widget.controller.isDemo ||
                                  widget.controller.status ==
                                      BackendStatus.ready,
                              onStopReceiving: widget.controller.isDemo
                                  ? null
                                  : () => widget.controller.stopReceiving(
                                      thread.id,
                                    ),
                              onDraft: (text) => widget.controller.updateDraft(
                                thread.id,
                                text,
                              ),
                              onSend: () => widget.controller.send(thread.id),
                              onAttach: _attach,
                              onConfigure: _configure,
                              onRemoveAttachment: (path) => widget.controller
                                  .removeAttachment(thread.id, path),
                            ),
                          ],
                        );
                        // Keep every control reachable in short windows and with enlarged text.
                        final minHeight =
                            640 +
                            (MediaQuery.textScalerOf(context).scale(14) - 14) *
                                16;
                        if (chatConstraints.maxHeight < minHeight) {
                          return SingleChildScrollView(
                            child: SizedBox(
                              height: math.max(
                                minHeight,
                                chatConstraints.maxHeight,
                              ),
                              child: content,
                            ),
                          );
                        }
                        return content;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
