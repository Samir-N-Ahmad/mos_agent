import 'chat.dart';

abstract interface class InferenceBackend {
  Uri get destination;
  Future<void> start();
  Future<List<ChatMode>> fetchModes();
  Future<String> newChat({required ChatMode mode});
  Stream<String> send(String chatId, String message);
  void stopReceiving(String chatId);
  void close();
}

enum BackendStatus { disconnected, starting, ready, failed }

enum InferenceFailureKind {
  connection,
  timeout,
  authentication,
  validation,
  rateLimit,
  server,
  protocol,
}

class InferenceFailure implements Exception {
  const InferenceFailure(this.kind, this.message);
  final InferenceFailureKind kind;
  final String message;
  @override
  String toString() => message;
}
