import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'workspace_shell.dart';

class HelpDeskApp extends StatelessWidget {
  const HelpDeskApp({
    super.key,
    this.demoMode = const bool.fromEnvironment('DEMO_MODE'),
  });
  final bool demoMode;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MOS Agent',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: WorkspaceShell(demoMode: demoMode),
  );
}
