import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_agent/app/help_desk_app.dart';
import 'package:mos_agent/app/workspace_shell.dart';

void main() {
  testWidgets(
    'A single history panel exposes profile and settings in its footer',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const HelpDeskApp(demoMode: true));
      expect(find.text('Chat History'), findsOneWidget);
      expect(find.byTooltip('Media'), findsNothing);
      expect(find.byTooltip('Chats'), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('chat-list-pane'))).dx,
        0,
      );
      final footer = find.byKey(const ValueKey('history-account-footer'));
      expect(tester.getRect(footer).top, greaterThan(650));
      final input = find.byKey(const ValueKey('message-input'));
      await tester.enterText(input, 'Keep this draft');
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AlertDialog, 'Profile'), findsOneWidget);
      expect(find.textContaining('not signed in'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AlertDialog, 'Settings'), findsOneWidget);
      expect(find.text('Agent and chat configuration'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(input).controller!.text,
        'Keep this draft',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Compact enlarged layout keeps account actions reachable through history',
    (tester) async {
      tester.view.physicalSize = const Size(480, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: const WorkspaceShell(),
        ),
      );
      for (final action in ['Profile', 'Settings']) {
        await tester.tap(find.byTooltip('Choose chat'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(action));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AlertDialog, action), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Choose chat'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
