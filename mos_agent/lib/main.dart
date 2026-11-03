import 'dart:ui';

import 'package:flutter/material.dart';

import 'app/help_desk_app.dart';
import 'core/diagnostics/app_log.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final previousPrint = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null) AppLog.instance.add('Console', message);
    previousPrint(message, wrapWidth: wrapWidth);
  };
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLog.instance.add('Flutter error', details.toString());
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.instance.add('Unhandled error', '$error\n$stack');
    return false;
  };
  AppLog.instance.add('Application', 'MOS Agent started');
  runApp(const HelpDeskApp());
}
