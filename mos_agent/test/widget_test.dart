import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_agent/app/help_desk_app.dart';
import 'package:mos_agent/app/workspace_section.dart';
import 'package:mos_agent/app/workspace_shell.dart';
import 'package:mos_agent/shared/widgets/workspace_sidebar.dart';

void main() {
  testWidgets('Desktop sidebar fills height and switches active content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const HelpDeskApp());
    expect(tester.getSize(find.byType(WorkspaceSidebar)), const Size(60, 800));
    expect(find.text('Chats'), findsOneWidget);
    for (final section in WorkspaceSection.values) {
      await tester.tap(find.byTooltip(section.title));
      await tester.pumpAndSettle();
      expect(find.text(section.title), findsOneWidget);
      if (section == WorkspaceSection.chats) {
        expect(find.byKey(const ValueKey('message-input')), findsOneWidget);
      } else {
        expect(find.text(section.emptyTitle), findsOneWidget);
      }
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, section.selectedIcon),
      );
      expect(button.isSelected, isTrue);
    }
    final logout = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.logout),
    );
    expect(logout.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compact window and enlarged text avoid overflow', (
    tester,
  ) async {
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
    for (final section in WorkspaceSection.values) {
      await tester.tap(find.byTooltip(section.title));
      await tester.pumpAndSettle();
      expect(find.text(section.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
