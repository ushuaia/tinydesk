import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/explorer_state_store.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/document_handle.dart';
import 'package:tinydesk/features/documents/remote_file_browser_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_tunnel_session.dart';

class _TabHandle extends DocumentHandle {
  _TabHandle(this.file);

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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('reopening the browser restores the last project and pages',
      (tester) async {
    const a = RemoteFile(name: 'a.txt', path: '/p/a.txt', isDirectory: false);
    const b = RemoteFile(name: 'b.txt', path: '/p/b.txt', isDirectory: false);

    // First visit: open both files (b active).
    await tester.pumpWidget(MaterialApp(
      home: RemoteFileBrowserPage(
        session: FakeTunnelSession(
          home: '/p',
          files: const [a, b],
        ),
        initialPath: '/p',
        projectRoot: '/p',
        hostId: 'h1',
        floating: false,
        documentHandleFactory: ({
          required session,
          required file,
          required hostId,
          required projectRoot,
          required userScope,
        }) =>
            _TabHandle(file),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('b.txt'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
      1,
    );

    // Fresh page: the browser comes back exactly where it was.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(
      home: RemoteFileBrowserPage(
        session: FakeTunnelSession(
          home: '/p',
          files: const [a, b],
        ),
        initialPath: '/p',
        projectRoot: '/p',
        hostId: 'h1',
        floating: false,
        documentHandleFactory: ({
          required session,
          required file,
          required hostId,
          required projectRoot,
          required userScope,
        }) =>
            _TabHandle(file),
      ),
    ));
    await tester.pumpAndSettle();

    final state = await ExplorerStateStore().load('h1');
    expect(state.openDocPaths, ['/p/a.txt', '/p/b.txt']);
    final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.index, 1);
    expect(find.text('body-a.txt', skipOffstage: false), findsOneWidget);
    expect(find.text('body-b.txt'), findsOneWidget);
  });
}
