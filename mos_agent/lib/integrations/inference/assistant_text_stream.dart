import '../../features/chats/domain/inference_backend.dart';

/// Accept plain text, or the ChatML envelope observed in the local service.
/// Buffer partial delimiters so prompt text and control tokens never flash in UI.
Stream<String> assistantTextStream(
  Stream<String> source, {
  String? userMessage,
}) async* {
  const start = '<|im_start|>';
  final assistant = userMessage == null
      ? '<|im_start|>assistant\n'
      : '<|im_start|>user\n$userMessage<|im_end|>\n<|im_start|>assistant\n';
  final assistantCrLf = userMessage == null
      ? '<|im_start|>assistant\r\n'
      : '<|im_start|>user\r\n$userMessage<|im_end|>\r\n<|im_start|>assistant\r\n';
  const stops = ['<|im_end|>', '<|im_start|>', '<|endoftext|>'];
  var buffer = '';
  var mode = 0; // 0 = detect, 1 = plain text, 2 = envelope, 3 = answer.
  var ended = false;
  await for (final chunk in source) {
    if (ended) continue;
    buffer += chunk;
    if (mode == 0) {
      if (buffer.startsWith(start)) {
        mode = 2;
      } else if (start.startsWith(buffer)) {
        continue;
      } else {
        mode = 1;
      }
    }
    if (mode == 1) {
      yield buffer;
      buffer = '';
      continue;
    }
    if (mode == 2) {
      final match = buffer.indexOf(assistant);
      final crlfMatch = buffer.indexOf(assistantCrLf);
      if (match < 0 && crlfMatch < 0) continue;
      final index = match >= 0 ? match : crlfMatch;
      final length = match >= 0 ? assistant.length : assistantCrLf.length;
      buffer = buffer.substring(index + length);
      mode = 3;
    }
    var stopIndex = -1;
    for (final stop in stops) {
      final index = buffer.indexOf(stop);
      if (index >= 0 && (stopIndex < 0 || index < stopIndex)) stopIndex = index;
    }
    if (stopIndex >= 0) {
      if (stopIndex > 0) yield buffer.substring(0, stopIndex);
      buffer = '';
      ended = true;
      continue;
    }
    var held = 0;
    for (final stop in stops) {
      for (
        var length = 1;
        length < stop.length && length <= buffer.length;
        length++
      ) {
        if (buffer.endsWith(stop.substring(0, length)) && length > held) {
          held = length;
        }
      }
    }
    final visible = buffer.substring(0, buffer.length - held);
    if (visible.isNotEmpty) yield visible;
    buffer = buffer.substring(buffer.length - held);
  }
  if (mode == 2) {
    throw const InferenceFailure(
      InferenceFailureKind.protocol,
      'The response contained a prompt but no assistant answer.',
    );
  }
  if (mode == 3 && buffer.isNotEmpty) {
    throw const InferenceFailure(
      InferenceFailureKind.protocol,
      'The response ended inside a control token. The displayed answer may be incomplete.',
    );
  }
  if (!ended && buffer.isNotEmpty) yield buffer;
}
