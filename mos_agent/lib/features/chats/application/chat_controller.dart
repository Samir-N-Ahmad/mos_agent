import 'package:flutter/foundation.dart';

import '../domain/chat.dart';
import '../domain/inference_backend.dart';

class DemoChatResponder implements ChatResponder {
  @override
  Future<ChatMessage> respond(ChatThread thread, ChatMessage message) async {
    if (thread.mode.name.toUpperCase() == 'CLASSIFICATION') {
      return ChatMessage(text: 'request', fromUser: false);
    }
    final details = thread.style == ReplyStyle.detailed
        ? '\n\nA connected agent would use approved sources and return an editable response. No files were uploaded or analyzed, and no ticket actions were performed.'
        : '\nNo model is connected and no external actions were performed.';
    return ChatMessage(
      text:
          'Demo ${thread.role.name} response: your message was added to this local preview.$details',
      fromUser: false,
    );
  }
}

class ChatController extends ChangeNotifier {
  ChatController({ChatResponder? responder, InferenceBackend? backend})
    : _responder = responder ?? DemoChatResponder(),
      _backend = backend {
    if (backend != null) {
      _threads.clear();
      _threads.add(ChatThread(id: 'local-0', title: 'New chat'));
      _selectedId = 'local-0';
      _modes = const [];
    }
  }

  final ChatResponder _responder;
  final InferenceBackend? _backend;
  BackendStatus status = BackendStatus.disconnected;
  String? connectionError;
  bool creatingChat = false;
  bool get isDemo => _backend == null;
  Uri? get destination => _backend?.destination;
  final Map<String, Object> _runs = {};
  List<ChatMode> _modes = ChatMode.demoModes;
  List<ChatMode> get modes => List.unmodifiable(_modes);
  ChatMode? get defaultMode =>
      _modes.where((mode) => mode.name.toUpperCase() == 'CHAT').firstOrNull ??
      _modes.firstOrNull;

  Future<void> connect() async {
    if (_backend == null ||
        status == BackendStatus.starting ||
        status == BackendStatus.ready) {
      return;
    }
    status = BackendStatus.starting;
    connectionError = null;
    notifyListeners();
    try {
      await _backend.start();
      if (_disposed) return;
      final discovered = await _backend.fetchModes();
      if (_disposed) return;
      if (discovered.isEmpty) {
        throw const InferenceFailure(
          InferenceFailureKind.protocol,
          'The service returned no modes. No chat was created.',
        );
      }
      _modes = List.unmodifiable(discovered);
      if (active.backendId == null) {
        final localId = active.id;
        final mode = defaultMode!;
        final remoteId = await _backend.newChat(mode: mode);
        if (_disposed) return;
        _replace(thread(localId).copyWith(backendId: remoteId, mode: mode));
      }
      status = BackendStatus.ready;
    } catch (error) {
      if (_disposed) return;
      status = BackendStatus.failed;
      connectionError = _failureText(error);
    }
    if (!_disposed) notifyListeners();
  }

  String _failureText(Object error) => error is InferenceFailure
      ? error.message
      : 'The inference service request failed. Your draft is preserved.';

  final List<ChatThread> _threads = [
    ChatThread(
      id: 'welcome',
      title: 'Getting started',
      messages: [
        ChatMessage(
          text: 'Welcome to your help-desk workspace. Choose a chat or start a new one. This is a local demo; no AI provider is connected.',
          fromUser: false,
        ),
      ],
    ),
    ChatThread(
      id: 'draft',
      title: 'Reply drafting · demo',
      messages: [
        ChatMessage(
          text: 'Help me prepare a reply to a support request.',
          fromUser: true,
        ),
        ChatMessage(
          text: 'Demo conversation: share the issue and approved guidance to start drafting. No customer data is loaded.',
          fromUser: false,
        ),
      ],
    ),
  ];
  String _selectedId = 'welcome';
  int _nextId = 0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _runs.clear();
    _backend?.close();
    super.dispose();
  }

  List<ChatThread> get threads => List.unmodifiable(_threads);
  ChatThread get active => _threads.firstWhere((t) => t.id == _selectedId);
  ChatThread thread(String id) => _threads.firstWhere((t) => t.id == id);

  void select(String id) {
    if (!_threads.any((t) => t.id == id)) return;
    _selectedId = id;
    notifyListeners();
  }

  Future<void> newChat({ChatMode? mode}) async {
    if (_disposed || creatingChat || status == BackendStatus.starting) return;
    if (_backend != null && status != BackendStatus.ready) {
      connectionError = 'Start inference before creating a backend chat.';
      notifyListeners();
      return;
    }
    final selected = mode ?? defaultMode;
    final selectedMode = _modes.where((item) => item == selected).firstOrNull;
    if (selectedMode == null) {
      connectionError =
          'Choose an available backend mode before creating a chat.';
      notifyListeners();
      return;
    }
    creatingChat = true;
    connectionError = null;
    notifyListeners();
    try {
      final remoteId = _backend == null
          ? null
          : await _backend.newChat(mode: selectedMode);
      if (_disposed) return;
      final chat = ChatThread(
        id: 'chat-${_nextId++}',
        mode: selectedMode,
        title: 'New chat',
        backendId: remoteId,
      );
      _threads.insert(0, chat);
      _selectedId = chat.id;
    } catch (error) {
      if (!_disposed) connectionError = _failureText(error);
    } finally {
      creatingChat = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _replace(ChatThread next) {
    if (_disposed) return;
    _threads[_threads.indexWhere((t) => t.id == next.id)] = next;
    notifyListeners();
  }

  void updateDraft(String id, String draft) {
    final current = thread(id);
    if (!current.sending) _replace(current.copyWith(draft: draft));
  }

  void addAttachments(String id, List<ChatAttachment> files) {
    final current = thread(id);
    if (current.sending) return;
    final byPath = {
      for (final file in [...current.attachments, ...files]) file.path: file,
    };
    _replace(current.copyWith(attachments: byPath.values.toList()));
  }

  void removeAttachment(String id, String path) {
    final current = thread(id);
    if (!current.sending) {
      _replace(
        current.copyWith(
          attachments: current.attachments
              .where((f) => f.path != path)
              .toList(),
        ),
      );
    }
  }

  void configure(String id, {ReplyStyle? style, AgentRole? role}) {
    final current = thread(id);
    if (!current.sending) _replace(current.copyWith(style: style, role: role));
  }

  Future<bool> send(String id) async {
    if (_backend != null) return _sendToBackend(id);
    final current = thread(id);
    if (current.sending ||
        (current.draft.trim().isEmpty && current.attachments.isEmpty)) {
      return false;
    }
    final message = ChatMessage(
      text: current.draft.trim(),
      fromUser: true,
      attachments: current.attachments,
    );
    _replace(current.copyWith(sending: true));
    try {
      final response = await _responder.respond(current, message);
      _replace(
        current.copyWith(
          title: current.title == 'New chat' && message.text.isNotEmpty
              ? String.fromCharCodes(message.text.runes.take(48))
              : current.title,
          messages: [...current.messages, message, response],
          draft: '',
          attachments: [],
          sending: false,
        ),
      );
      return true;
    } catch (_) {
      _replace(
        current.copyWith(
          sending: false,
          error: 'Could not send. Your draft and attachments are preserved. Try again.',
        ),
      );
      return false;
    }
  }

  Future<bool> _sendToBackend(String id) async {
    var current = thread(id);
    if (_disposed || current.sending || current.draft.trim().isEmpty) {
      return false;
    }
    if (status != BackendStatus.ready) {
      _replace(
        current.copyWith(
          error: 'Start inference before sending. Your draft is preserved.',
        ),
      );
      return false;
    }
    if (current.attachments.isNotEmpty) {
      _replace(
        current.copyWith(
          error: 'This API supports text only. Remove attachments before sending; no files were transmitted.',
        ),
      );
      return false;
    }
    final token = Object();
    _runs[id] = token;
    _replace(current.copyWith(sending: true));
    var appended = false;
    try {
      if (current.backendId == null) {
        final remoteId = await _backend!.newChat(mode: current.mode);
        if (_runs[id] != token || _disposed) return false;
        current = thread(id).copyWith(backendId: remoteId);
        _replace(current);
      }
      final userMessage = ChatMessage(
        text: current.draft.trim(),
        fromUser: true,
      );
      _replace(
        current.copyWith(
          sending: true,
          messages: [
            ...current.messages,
            userMessage,
            ChatMessage(
              text: '',
              fromUser: false,
              delivery: MessageDelivery.streaming,
            ),
          ],
        ),
      );
      appended = true;
      var answer = '';
      await for (final delta in _backend!.send(
        current.backendId!,
        userMessage.text,
      )) {
        if (_runs[id] != token || _disposed) return false;
        answer += delta;
        final latest = thread(id);
        _replace(
          latest.copyWith(
            messages: [
              ...latest.messages.take(latest.messages.length - 1),
              ChatMessage(
                text: answer,
                fromUser: false,
                delivery: MessageDelivery.streaming,
              ),
            ],
          ),
        );
      }
      if (_runs[id] != token || _disposed) return false;
      if (answer.trim().isEmpty) {
        throw const InferenceFailure(
          InferenceFailureKind.protocol,
          'The service returned an empty answer. Your draft is kept.',
        );
      }
      final latest = thread(id);
      _replace(
        latest.copyWith(
          title: latest.title == 'New chat'
              ? String.fromCharCodes(userMessage.text.runes.take(48))
              : latest.title,
          messages: [
            ...latest.messages.take(latest.messages.length - 1),
            ChatMessage(text: answer, fromUser: false),
          ],
          sending: false,
          draft: '',
        ),
      );
      return true;
    } catch (error) {
      if (_runs[id] != token || _disposed) return false;
      final latest = thread(id);
      _replace(
        latest.copyWith(
          sending: false,
          error: _failureText(error),
          messages: appended
              ? [
                  ...latest.messages.take(latest.messages.length - 1),
                  ChatMessage(
                    text: latest.messages.last.text,
                    fromUser: false,
                    delivery: MessageDelivery.interrupted,
                  ),
                ]
              : latest.messages,
        ),
      );
      return false;
    } finally {
      if (_runs[id] == token) _runs.remove(id);
    }
  }

  void stopReceiving(String id) {
    final current = thread(id);
    if (_backend == null || !current.sending) return;
    _runs.remove(id);
    if (current.backendId != null) _backend.stopReceiving(current.backendId!);
    final messages = current.messages.toList();
    if (messages.isNotEmpty &&
        messages.last.delivery == MessageDelivery.streaming) {
      messages[messages.length - 1] = ChatMessage(
        text: messages.last.text,
        fromUser: false,
        delivery: MessageDelivery.interrupted,
      );
    }
    _replace(
      current.copyWith(
        sending: false,
        messages: messages,
        error: 'Stopped receiving. Server generation may continue. Your draft is kept; resend only if safe.',
      ),
    );
  }
}
