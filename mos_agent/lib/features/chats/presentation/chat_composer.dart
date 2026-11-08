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
    required this.onRemoveAttachment,
    required this.pickingFiles,
    this.demoMode = true,
    this.sendingAllowed = true,
    this.onCancelGeneration,
  });
  final ChatThread thread;
  final ValueChanged<String> onDraft;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final ValueChanged<String> onRemoveAttachment;
  final bool pickingFiles;
  final bool demoMode;
  final bool sendingAllowed;
  final VoidCallback? onCancelGeneration;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late final TextEditingController _text = TextEditingController(
    text: widget.thread.draft,
  );
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);
  double _height = 48;

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
    final hasContent =
        widget.thread.draft.trim().isNotEmpty ||
        widget.thread.attachments.isNotEmpty;
    final action = widget.thread.sending && widget.onCancelGeneration != null
        ? IconButton(
            tooltip: widget.thread.cancelling
                ? 'Cancelling generation…'
                : 'Cancel generation',
            onPressed: widget.thread.cancelling
                ? null
                : widget.onCancelGeneration,
            icon: const Icon(Icons.stop),
          )
        : widget.thread.sending
        ? const Padding(
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
        : ExcludeSemantics(
            excluding: !hasContent,
            child: Opacity(
              opacity: hasContent ? 1 : 0,
              child: IconButton(
                tooltip: 'Send message',
                onPressed: canSend ? widget.onSend : null,
                icon: const Icon(Icons.arrow_upward),
              ),
            ),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 28, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: IconButton(
              key: const ValueKey('composer-attachment'),
              tooltip: widget.pickingFiles
                  ? 'Choosing files…'
                  : widget.demoMode
                  ? 'Attach files'
                  : 'Attachments unavailable — backend supports text only',
              onPressed: busy || !widget.demoMode ? null : widget.onAttach,
              icon: const Icon(Icons.add, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              key: const ValueKey('composer-pill'),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(32),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ResizeHandle(
                    key: const ValueKey('composer-resize'),
                    axis: Axis.vertical,
                    label: 'Resize message input',
                    showGrip: false,
                    thickness: 6,
                    onDelta: (delta) => setState(
                      () => _height = (_height - delta).clamp(48, 240),
                    ),
                  ),
                  if (widget.thread.attachments.isNotEmpty)
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                deleteButtonTooltipMessage:
                                    'Remove ${file.name}',
                                onDeleted: busy
                                    ? null
                                    : () =>
                                          widget.onRemoveAttachment(file.path),
                              ),
                            ),
                        ],
                      ),
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final style = Theme.of(context).textTheme.bodyLarge!;
                      // Start as a slim pill, then grow for multiline/wrapped drafts.
                      final painter =
                          TextPainter(
                            text: TextSpan(
                              text: widget.thread.draft.isEmpty
                                  ? ' '
                                  : widget.thread.draft,
                              style: style,
                            ),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                            maxLines: 8,
                          )..layout(
                            maxWidth: (constraints.maxWidth - 84).clamp(
                              1,
                              double.infinity,
                            ),
                          );
                      final measured = (painter.height + 16)
                          .clamp(_height, 240)
                          .toDouble();
                      painter.dispose();
                      return SizedBox(
                        key: const ValueKey('message-input-area'),
                        height: measured,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                key: const ValueKey('message-input'),
                                controller: _text,
                                focusNode: _focus,
                                readOnly: widget.thread.sending,
                                style: style,
                                expands: true,
                                minLines: null,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                textAlignVertical: measured > 60
                                    ? TextAlignVertical.top
                                    : TextAlignVertical.center,
                                onChanged: widget.onDraft,
                                decoration: const InputDecoration(
                                  hintText: 'Message MOS Agent…',
                                  contentPadding: EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    8,
                                    8,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                right: 6,
                                bottom: 3,
                              ),
                              child: action,
                            ),
                          ],
                        ),
                      );
                    },
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
