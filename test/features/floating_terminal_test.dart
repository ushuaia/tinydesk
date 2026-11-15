import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/core/app_session_manager.dart';
import 'package:tinydesk/features/terminal/floating_terminal_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ball expands into the floating window', (tester) async {
    final manager = AppSessionManager(backgroundTasks: false);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      manager.dispose();
    });
    manager.terminal.visible = true;
    manager.terminal.expanded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingTerminalHost(manager: manager),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.terminal), findsOneWidget);

    await tester.tap(find.byIcon(Icons.terminal));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.textContaining('Terminal'), findsWidgets);
  });

  testWidgets('minimize returns to the ball and close hides it', (tester) async {
    final manager = AppSessionManager(backgroundTasks: false);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      manager.dispose();
    });
    manager.terminal.visible = true;
    manager.terminal.expanded = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingTerminalHost(manager: manager),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(find.byIcon(Icons.terminal), findsOneWidget);

    await tester.tap(find.byIcon(Icons.terminal));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(manager.terminal.visible, isFalse);
    expect(find.byIcon(Icons.terminal), findsNothing);
  });
}
