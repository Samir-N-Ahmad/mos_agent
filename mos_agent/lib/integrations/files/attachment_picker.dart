import 'package:file_selector/file_selector.dart';

import '../../features/chats/domain/chat.dart';

abstract interface class AttachmentPicker {
  Future<List<ChatAttachment>> pick();
}

class NativeAttachmentPicker implements AttachmentPicker {
  @override
  Future<List<ChatAttachment>> pick() async {
    final files = await openFiles();
    return files
        .map((file) => ChatAttachment(path: file.path, name: file.name))
        .toList();
  }
}
