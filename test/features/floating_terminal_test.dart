import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/platform/window_close.dart';
import 'package:tinydesk/session/app_session_manager.dart';
import 'package:tinydesk/features/terminal/floating_terminal_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> sendWindowEvent(String method) async {
  final data =
      const StandardMethodCodec().encodeMethodCall(MethodCall(method)) as ByteData;
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage('opencode/window', data, (response) {});
}

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

    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.remove), findsNothing);
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
    WindowCloseHandler.register(
      () async => manager.terminal.close(),
      onMinimizeRequested: () async => manager.terminal.minimize(),
      onZoomRequested: () async => manager.terminal.toggleExpanded(),
    );
    addTearDown(WindowCloseHandler.unregister);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingTerminalHost(manager: manager),
        ),
      ),
    );
    await tester.pump();

    // The yellow light collapses the window to the ball.
    await sendWindowEvent('minimizeRequested');
    await tester.pump();
    expect(find.byIcon(Icons.terminal), findsOneWidget);

    // Tapping the ball re-opens the window.
    await tester.tap(find.byIcon(Icons.terminal));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The red light closes it (the terminal is the visible overlay).
    await sendWindowEvent('closeRequested');
    await tester.pump();
    expect(manager.terminal.visible, isFalse);
    expect(find.byIcon(Icons.terminal), findsNothing);
  });
}
