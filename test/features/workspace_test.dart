import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/core/connection_state.dart';
import 'package:tinydesk/features/workspace/workspace_page.dart';

void main() {
  testWidgets('shows retry on failed phase', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspacePage(
          title: 'dev box',
          snapshot: const ConnectionSnapshot(
            phase: ConnectionPhase.failed,
            message: '密钥被拒绝',
          ),
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('密钥被拒绝'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('shows reconnect overlay', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspacePage(
          title: 'dev box',
          snapshot: const ConnectionSnapshot(
            phase: ConnectionPhase.reconnecting,
          ),
        ),
      ),
    );

    expect(find.text('网络中断，正在重连…'), findsOneWidget);
  });

  testWidgets('shows floating controls in ready phase', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspacePage(
          title: 'dev box',
          snapshot: const ConnectionSnapshot(phase: ConnectionPhase.ready),
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byIcon(Icons.link_off), findsNothing);
    expect(find.byIcon(Icons.terminal), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
    expect(find.text('dev box'), findsOneWidget);
  });

  testWidgets('terminal button invokes onTerminal', (tester) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspacePage(
          title: 'dev box',
          snapshot: const ConnectionSnapshot(phase: ConnectionPhase.ready),
          onTerminal: () => called = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.terminal));
    await tester.pump();

    expect(called, isTrue);
  });

  testWidgets('add-host button invokes onAddHost', (tester) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspacePage(
          snapshot: const ConnectionSnapshot(phase: ConnectionPhase.ready),
          tabs: const [
            WorkspaceTab(
              hostId: 'h1',
              name: 'dev box',
              phase: ConnectionPhase.ready,
            ),
          ],
          activeHostId: 'h1',
          onAddHost: () => called = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(called, isTrue);
  });

  testWidgets('session chips switch hosts', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspacePage(
          snapshot: const ConnectionSnapshot(phase: ConnectionPhase.ready),
          tabs: const [
            WorkspaceTab(
              hostId: 'h1',
              name: 'dev box',
              phase: ConnectionPhase.ready,
            ),
            WorkspaceTab(
              hostId: 'h2',
              name: 'prod box',
              phase: ConnectionPhase.ready,
            ),
          ],
          activeHostId: 'h1',
          onSelectTab: (id) => selected = id,
        ),
      ),
    );

    await tester.tap(find.text('prod box'));
    await tester.pump();

    expect(selected, 'h2');
  });
}
