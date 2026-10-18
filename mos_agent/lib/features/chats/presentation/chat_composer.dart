import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/resize_handle.dart';
import '../domain/chat.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.thread,
    required this.onDraft,
    required this.onSend,
    required this.onAttach,
    required this.onConfigure,
    required this.onRemoveAttachment,
    required this.pickingFiles,
    this.demoMode = true,
    this.sendingAllowed = true,
    this.onStopReceiving,
  });
  final ChatThread thread;
  final ValueChanged<String> onDraft;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onConfigure;
  final ValueChanged<String> onRemoveAttachment;
  final bool pickingFiles;
  final bool demoMode;
  final bool sendingAllowed;
  final VoidCallback? onStopReceiving;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late final TextEditingController _text = TextEditingController(
    text: widget.thread.draft,
  );
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);
  double _height = 100;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (!_text.value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      if (event is KeyDownEvent && !widget.thread.sending) {
        final selection = _text.selection;
        final start = selection.isValid ? selection.start : _text.text.length;
        final end = selection.isValid ? selection.end : start;
        final next = _text.text.replaceRange(start, end, '\n');
        _text.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: start + 1),
        );
        widget.onDraft(next);
      }
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        !widget.thread.sending &&
        !widget.pickingFiles &&
        widget.sendingAllowed) {
      widget.onSend();
    }
    return KeyEventResult.handled;
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_text.text != widget.thread.draft) {
      _text.value = TextEditingValue(
        text: widget.thread.draft,
        selection: TextSelection.collapsed(offset: widget.thread.draft.length),
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final busy = widget.thread.sending || widget.pickingFiles;
    final canSend =
        widget.sendingAllowed &&
        !busy &&
        (widget.thread.draft.trim().isNotEmpty ||
            widget.thread.attachments.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ResizeHandle(
                  key: const ValueKey('composer-resize'),
                  axis: Axis.vertical,
                  label: 'Resize message input',
                  onDelta: (delta) => setState(
                    () => _height = (_height - delta).clamp(100, 260),
                  ),
                ),
                if (widget.thread.attachments.isNotEmpty)
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final file in widget.thread.attachments)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InputChip(
                              avatar: const Icon(Icons.attach_file, size: 16),
                              label: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 180,
                                ),
                                child: Text(
                                  file.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              deleteButtonTooltipMessage: 'Remove ${file.name}',
                              onDeleted: busy
                                  ? null
                                  : () => widget.onRemoveAttachment(file.path),
                            ),
                          ),
                      ],
                    ),
                  ),
                SizedBox(
                  key: const ValueKey('message-input-area'),
                  height: _height,
                  child: TextField(
                    key: const ValueKey('message-input'),
                    controller: _text,
                    focusNode: _focus,
                    readOnly: widget.thread.sending,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    textAlignVertical: TextAlignVertical.top,
                    onChanged: widget.onDraft,
                    decoration: const InputDecoration(
                      hintText: 'Message your agent…',
                      labelText: 'Message',
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      contentPadding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: widget.pickingFiles
                            ? 'Choosing files…'
                            : widget.demoMode
                            ? 'Attach files'
                            : 'Attachments unavailable — backend supports text only',
                        onPressed: busy || !widget.demoMode
                            ? null
                            : widget.onAttach,
                        icon: const Icon(Icons.add),
                      ),
                      IconButton(
                        tooltip: 'Agent and chat configuration',
                        onPressed: busy ? null : widget.onConfigure,
                        icon: const Icon(Icons.tune),
                      ),
                      const Spacer(),
                      if (widget.thread.sending &&
                          widget.onStopReceiving != null)
                        IconButton.filled(
                          tooltip: 'Stop receiving response',
                          onPressed: widget.onStopReceiving,
                          icon: const Icon(Icons.stop),
                        )
                      else if (widget.thread.sending)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: 'Responding',
                            ),
                          ),
                        )
                      else
                        IconButton.filled(
                          tooltip: 'Send message',
                          onPressed: canSend ? widget.onSend : null,
                          icon: const Icon(Icons.arrow_upward),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.demoMode
                ? 'Local demo · Files stay on this device · Chats last for this session'
                : 'Text-only backend · Chats last for this session',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
