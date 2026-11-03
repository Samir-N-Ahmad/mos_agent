import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/diagnostics/app_log.dart';

/// A native macOS window shares a bounded text snapshot, not a second model client.
class LogWindow {
  static const _channel = MethodChannel('mos_agent/diagnostics');
  final AppLog log;
  Timer? _timer;
  bool _listening = false;
  bool _disposed = false;
  LogWindow(this.log);

  Future<void> open() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
      throw UnsupportedError(
        'The separate logs window is currently available on macOS.',
      );
    }
    final visible = await _channel.invokeMethod<bool>('open', log.text);
    if (visible != true) throw StateError('The logs window could not open.');
    if (_disposed || _listening) return;
    log.addListener(_schedule);
    _listening = true;
  }

  void _schedule() {
    _timer ??= Timer(const Duration(milliseconds: 150), () async {
      _timer = null;
      try {
        await _channel.invokeMethod<void>('update', log.text);
      } on PlatformException catch (_) {
        // The diagnostics window must not interrupt generation.
      } on MissingPluginException catch (_) {
        // The platform runner may be shutting down.
      }
    });
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_listening) log.removeListener(_schedule);
  }
}
