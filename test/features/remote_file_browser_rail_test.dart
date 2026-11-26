import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/features/documents/explorer_tree.dart';
import 'package:tinydesk/features/documents/remote_file_browser_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_tunnel_session.dart';

Widget page() => MaterialApp(
      home: RemoteFileBrowserPage(
        session: FakeTunnelSession(),
        initialPath: '/home/test',
        projectRoot: '/home/test',
        hostId: 'h1',
        floating: true,
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('desktop: the sidebar sits beside the content and never auto-hides',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    // Entering the page always opens the tree (persisted rail state).
    final tree = find.byType(ExplorerTree);
    expect(tree, findsOneWidget);
    // The tree is a real pane: content starts right of it.
    expect(tester.getTopLeft(tree).dx, 0);
    expect(tester.getTopRight(tree).dx, lessThan(1200));

    // Interacting with the content area keeps the sidebar open.
    await tester.tapAt(const Offset(900, 400));
    await tester.pumpAndSettle();
    expect(tree, findsOneWidget);

    // The toolbar toggle collapses it back to full-width content.
    await tester.tap(find.byIcon(Icons.account_tree_outlined).first);
    await tester.pumpAndSettle();
    expect(tree, findsNothing);
  });

  testWidgets('mobile: the tree overlays the content and closes on tap',
      (tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    // Entering the page opens the overlay drawer.
    expect(find.byType(ExplorerTree), findsOneWidget);

    // Classic drawer: interacting with the covered content closes it.
    await tester.tapAt(const Offset(400, 400));
    await tester.pumpAndSettle();
    expect(find.byType(ExplorerTree), findsNothing);
  });
}
