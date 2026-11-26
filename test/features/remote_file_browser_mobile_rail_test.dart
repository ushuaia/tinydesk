import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/document_handle.dart';
import 'package:tinydesk/features/documents/explorer_tree.dart';
import 'package:tinydesk/features/documents/remote_file_browser_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_tunnel_session.dart';

class _Handle extends DocumentHandle {
  _Handle(this.file);

  final RemoteFile file;

  @override
  String get title => file.name;

  @override
  Widget buildBody(BuildContext context) => Text('body-${file.name}');

  @override
  Future<bool> confirmClose(BuildContext context) async => true;

  @override
  Future<void> close() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the tree toggle stays reachable on a phone with a doc open',
      (tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: RemoteFileBrowserPage(
        session: FakeTunnelSession(
          home: '/p',
          files: const [
            RemoteFile(
              name: 'a.txt',
              path: '/p/a.txt',
              isDirectory: false,
            ),
          ],
        ),
        initialPath: '/p',
        projectRoot: '/p',
        hostId: 'h1',
        floating: true,
        documentHandleFactory: ({
          required session,
          required file,
          required hostId,
          required projectRoot,
          required userScope,
        }) =>
            _Handle(file),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();
    expect(find.text('body-a.txt'), findsOneWidget);

    // The drawer closed after the pick; the toolbar toggle is still there.
    final toggle = find.byIcon(Icons.account_tree_outlined);
    expect(toggle, findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.byType(ExplorerTree), findsOneWidget);
  });
}
