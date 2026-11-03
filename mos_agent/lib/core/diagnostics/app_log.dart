import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Session-only diagnostics. Never persists prompts, credentials, or responses.
/// Raw API response bodies are included at the user's request.
class AppLog extends ChangeNotifier {
  AppLog({this.maxCharacters = 512 * 1024, this.maxEntries = 1000});
  static final instance = AppLog();
  final int maxCharacters;
  final int maxEntries;
  final Queue<String> _entries = Queue();
  int _characters = 0;

  String get text => _entries.join('\n');

  void add(String category, String message) {
    final prefix = '[${DateTime.now().toIso8601String()}] $category\n';
    final available = maxCharacters - prefix.length - 1;
    if (available <= 0) return;
    final body = message.length > available
        ? message.substring(message.length - available)
        : message;
    final entry = '$prefix$body\n';
    _entries.add(entry);
    _characters += entry.length;
    while (_characters > maxCharacters || _entries.length > maxEntries) {
      _characters -= _entries.removeFirst().length;
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    _characters = 0;
    notifyListeners();
  }
}
