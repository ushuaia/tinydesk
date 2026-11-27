import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/explorer_tree.dart';

import '../support/fake_tunnel_session.dart';

void main() {
  testWidgets('hovering a file row exposes its full name', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExplorerTree(
          session: FakeTunnelSession(
            files: const [
              RemoteFile(
                name: 'a-very-long-file-name-that-gets-truncated.txt',
                path: '/p/a-very-long-file-name-that-gets-truncated.txt',
                isDirectory: false,
              ),
            ],
          ),
          roots: const [RemoteFile(name: 'p', path: '/p', isDirectory: true)],
          currentPath: '/p',
          expandedPaths: const [],
          onDirectorySelected: (_) {},
          onFileSelected: (_) {},
          onExpandedChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byTooltip('a-very-long-file-name-that-gets-truncated.txt'),
      findsOneWidget,
    );
  });
}
