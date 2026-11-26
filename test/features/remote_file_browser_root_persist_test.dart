import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/explorer_state_store.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/document_handle.dart';
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

  testWidgets('picking a project persists it and moves the browser there',
      (tester) async {
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
        projectRoot: '/q',
        hostId: 'h1',
        floating: false,
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

    // Switch from the current project (p) to the other one (q).
    await tester.tap(find.byKey(const ValueKey('root-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('q'));
    await tester.pumpAndSettle();

    var state = await ExplorerStateStore().load('h1');
    expect(state.selectedRoot, '/q');
    expect(state.currentPath, '/q');

    // Opening a file afterwards must not rewrite the remembered project.
    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();

    state = await ExplorerStateStore().load('h1');
    expect(state.selectedRoot, '/q');
    expect(state.currentPath, '/q');
  });
}
