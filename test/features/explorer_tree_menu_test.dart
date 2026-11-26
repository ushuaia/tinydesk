import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/explorer_tree.dart';

import '../support/fake_tunnel_session.dart';

Future<void> pumpTree(
  WidgetTester tester,
  List<RemoteFile> roots, {
  List<RemoteFile> files = const [],
  void Function(RemoteFile)? onDownload,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ExplorerTree(
        session: FakeTunnelSession(files: files),
        roots: roots,
        currentPath: roots.first.path,
        expandedPaths: const [],
        onDirectorySelected: (_) {},
        onFileSelected: (_) {},
        onExpandedChanged: (_) {},
        onDownload: onDownload,
        onCopyPath: (_) async {},
        onToggleFavorite: (_) {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the row menu opens under the row', (tester) async {
    await pumpTree(
      tester,
      const [RemoteFile(name: 'p', path: '/p', isDirectory: true)],
      files: const [
        RemoteFile(name: 'a.txt', path: '/p/a.txt', isDirectory: false),
      ],
      onDownload: (_) {},
    );
    await tester.pumpAndSettle();

    final rowRect = tester.getRect(find.text('a.txt'));
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    final menuTop = tester.getTopLeft(find.text('Download')).dy;
    expect(menuTop, greaterThan(rowRect.bottom));
    expect(find.text('Copy path'), findsOneWidget);
  });

  testWidgets('a long menu is height-limited and scrolls', (tester) async {
    final roots = [
      for (var i = 1; i <= 20; i++)
        RemoteFile(name: 'p$i', path: '/p$i', isDirectory: true),
    ];
    await pumpTree(tester, roots);

    await tester.tap(find.byKey(const ValueKey('root-button')));
    await tester.pumpAndSettle();

    final panel = tester.widget<Material>(
      find.ancestor(
        of: find.text('p1'),
        matching: find.byType(Material),
      ).first,
    );
    // 20 items would need ~950px; the panel must cap at maxHeight instead.
    expect(panel.child, isNotNull);
    final box = tester.renderObject<RenderBox>(
      find.ancestor(
        of: find.text('p1'),
        matching: find.byType(Material),
      ).first,
    );
    expect(box.size.height, lessThan(20 * 46));
  });
}
