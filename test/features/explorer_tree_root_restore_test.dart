import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/explorer_tree.dart';

import '../support/fake_tunnel_session.dart';

class _PerRootSession extends FakeTunnelSession {
  @override
  Future<List<RemoteFile>> listDirectory(String path) async {
    if (path == '/a') {
      return const [
        RemoteFile(name: 'from-a.txt', path: '/a/from-a.txt', isDirectory: false),
      ];
    }
    if (path == '/b') {
      return const [
        RemoteFile(name: 'from-b.txt', path: '/b/from-b.txt', isDirectory: false),
      ];
    }
    return const [];
  }
}

RemoteFile _root(String name) =>
    RemoteFile(name: name, path: '/$name', isDirectory: true);

Widget _tree(List<RemoteFile> roots, String? selected) => MaterialApp(
      home: Scaffold(
        body: ExplorerTree(
          session: _PerRootSession(),
          roots: roots,
          currentPath: '/a',
          expandedPaths: const [],
          initialSelectedRoot: selected,
          onDirectorySelected: (_) {},
          onFileSelected: (_) {},
          onExpandedChanged: (_) {},
        ),
      ),
    );

void main() {
  testWidgets('a restored root wins once the project list arrives',
      (tester) async {
    // The page mounts the tree before the async project list is complete:
    // the remembered root is not in the list yet.
    await tester.pumpWidget(_tree(const [], '/b'));
    await tester.pumpAndSettle();
    expect(find.text('from-b.txt'), findsNothing);

    // Project roots arrive; the remembered root must take over.
    await tester.pumpWidget(_tree([_root('a'), _root('b')], '/b'));
    await tester.pumpAndSettle();

    expect(find.text('from-b.txt'), findsOneWidget);
    expect(find.text('from-a.txt'), findsNothing);
  });
}
