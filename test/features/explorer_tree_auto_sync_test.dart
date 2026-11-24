import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/explorer_tree.dart';

import '../support/fake_tunnel_session.dart';

class _SlowSession extends FakeTunnelSession {
  DateTime mtime = DateTime.utc(2026, 1, 1);
  final Completer<void> gate = Completer<void>();
  int listings = 0;

  @override
  Future<DateTime?> statModified(String path) async => mtime;

  @override
  Future<List<RemoteFile>> listDirectory(String path) async {
    listings++;
    if (listings > 1) await gate.future;
    return const [
      RemoteFile(name: 'keep.txt', path: '/p/keep.txt', isDirectory: false),
    ];
  }
}

void main() {
  testWidgets('a background refresh keeps the old listing visible',
      (tester) async {
    final session = _SlowSession();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExplorerTree(
          session: session,
          roots: const [
            RemoteFile(name: 'p', path: '/p', isDirectory: true),
          ],
          currentPath: '/p',
          expandedPaths: const ['root:/p'],
          onDirectorySelected: (_) {},
          onFileSelected: (_) {},
          onExpandedChanged: (_) {},
          autoSync: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('keep.txt'), findsOneWidget);

    session.mtime = DateTime.utc(2026, 2, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(find.text('keep.txt'), findsOneWidget);

    session.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('keep.txt'), findsOneWidget);
    expect(session.listings, 2);
  });
}
