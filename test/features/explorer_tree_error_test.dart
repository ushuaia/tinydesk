import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/explorer_tree.dart';

import '../support/fake_tunnel_session.dart';

class _FailingSession extends FakeTunnelSession {
  @override
  Future<List<RemoteFile>> listDirectory(String path) async {
    throw const FileSystemException('Operation not permitted', '/p');
  }
}

void main() {
  testWidgets('shows a readable error instead of an empty folder',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExplorerTree(
          session: _FailingSession(),
          roots: const [
            RemoteFile(name: 'p', path: '/p', isDirectory: true),
          ],
          currentPath: '/p',
          expandedPaths: const ['root:/p'],
          onDirectorySelected: (_) {},
          onFileSelected: (_) {},
          onExpandedChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Operation not permitted'), findsOneWidget);
  });
}
