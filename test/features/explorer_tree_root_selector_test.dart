import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/explorer_tree.dart';

import '../support/fake_tunnel_session.dart';

class _MultiRootSession extends FakeTunnelSession {
  @override
  Future<List<RemoteFile>> listDirectory(String path) async {
    switch (path) {
      case '/a':
        return const [
          RemoteFile(name: 'a.txt', path: '/a/a.txt', isDirectory: false),
        ];
      case '/b':
        return const [
          RemoteFile(name: 'b.txt', path: '/b/b.txt', isDirectory: false),
        ];
    }
    return const [];
  }
}

void main() {
  testWidgets('one root at a time, switched through the dropdown',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExplorerTree(
          session: _MultiRootSession(),
          roots: const [
            RemoteFile(name: 'a', path: '/a', isDirectory: true),
            RemoteFile(name: 'b', path: '/b', isDirectory: true),
          ],
          currentPath: '/a',
          expandedPaths: const [],
          onDirectorySelected: (_) {},
          onFileSelected: (_) {},
          onExpandedChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Only the current root's tree is visible; the other root lives in the
    // dropdown instead of being stacked below it.
    expect(find.text('a.txt'), findsOneWidget);
    expect(find.text('b.txt'), findsNothing);
    expect(find.text('/b'), findsNothing);

    final buttonRect = tester.getRect(find.byKey(const ValueKey('root-button')));
    await tester.tap(find.byKey(const ValueKey('root-button')));
    await tester.pumpAndSettle();

    // The menu panel opens right under the button.
    final menuTop = tester.getTopLeft(find.text('/b')).dy;
    expect(menuTop, greaterThan(buttonRect.bottom));

    await tester.tap(find.text('b'));
    await tester.pumpAndSettle();

    expect(find.text('b.txt'), findsOneWidget);
    expect(find.text('a.txt'), findsNothing);
  });
}
