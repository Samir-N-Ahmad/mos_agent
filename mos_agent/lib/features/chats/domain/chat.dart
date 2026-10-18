class ChatAttachment {
  const ChatAttachment({required this.path, required this.name});
  final String path;
  final String name;
}

enum MessageDelivery { complete, streaming, interrupted }

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.fromUser,
    this.delivery = MessageDelivery.complete,
    List<ChatAttachment> attachments = const [],
  }) : attachments = List.unmodifiable(attachments);
  final String text;
  final bool fromUser;
  final MessageDelivery delivery;
  final List<ChatAttachment> attachments;
}

/// Server-defined mode. Values are canonical URI segments, not enum ordinals.
class ChatMode {
  const ChatMode({required this.name, required this.value});
  final String name;
  final String value;
  String get label => name;

  // Fixtures only. Backend mode always uses the discovered catalogue.
  static const chat = ChatMode(name: 'Chat', value: '1');
  static const classification = ChatMode(name: 'Classification', value: '0');
  static const demoModes = [chat, classification];

  @override
  bool operator ==(Object other) => other is ChatMode && value == other.value;
  @override
  int get hashCode => value.hashCode;
}

enum ReplyStyle { concise, detailed }

enum AgentRole { assistant, triage, reply }

class ChatThread {
  ChatThread({
    required this.id,
    required this.title,
    List<ChatMessage> messages = const [],
    this.draft = '',
    this.mode = ChatMode.chat,
    List<ChatAttachment> attachments = const [],
    this.style = ReplyStyle.concise,
    this.role = AgentRole.assistant,
    this.sending = false,
    this.error,
    this.backendId,
  }) : messages = List.unmodifiable(messages),
       attachments = List.unmodifiable(attachments);

  final String id;
  final String title;
  final List<ChatMessage> messages;
  final String draft;
  final ChatMode mode;
  final List<ChatAttachment> attachments;
  final ReplyStyle style;
  final AgentRole role;
  final bool sending;
  final String? error;
  final String? backendId;

  ChatThread copyWith({
    String? title,
    List<ChatMessage>? messages,
    String? draft,
    List<ChatAttachment>? attachments,
    ReplyStyle? style,
    AgentRole? role,
    bool? sending,
    String? error,
    String? backendId,
    ChatMode? mode,
  }) => ChatThread(
    id: id,
    title: title ?? this.title,
    messages: messages ?? this.messages,
    draft: draft ?? this.draft,
    mode: mode ?? this.mode,
    attachments: attachments ?? this.attachments,
    style: style ?? this.style,
    role: role ?? this.role,
    sending: sending ?? this.sending,
    error: error,
    backendId: backendId ?? this.backendId,
  );
}

abstract interface class ChatResponder {
  Future<ChatMessage> respond(ChatThread thread, ChatMessage message);
}
