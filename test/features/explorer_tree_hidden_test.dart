import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/explorer_tree.dart';

import '../support/fake_tunnel_session.dart';

const _files = [
  RemoteFile(name: '.tinydesk', path: '/p/.tinydesk', isDirectory: true),
  RemoteFile(name: 'readme.md', path: '/p/readme.md', isDirectory: false),
];

void main() {
  testWidgets('hidden entries are shown or filtered by the flag',
      (tester) async {
    Future<void> pump(bool showHidden) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ExplorerTree(
            session: FakeTunnelSession(files: _files),
            roots: const [RemoteFile(name: 'p', path: '/p', isDirectory: true)],
            currentPath: '/p',
            expandedPaths: const [],
            showHidden: showHidden,
            onDirectorySelected: (_) {},
            onFileSelected: (_) {},
            onExpandedChanged: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await pump(true);
    expect(find.text('.tinydesk'), findsOneWidget);
    expect(find.text('readme.md'), findsOneWidget);

    await pump(false);
    expect(find.text('.tinydesk'), findsNothing);
    expect(find.text('readme.md'), findsOneWidget);
  });
}
