import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/document_handle.dart';
import 'package:tinydesk/features/documents/remote_file_browser_page.dart';
import 'package:tinydesk/ssh/tunnel_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_tunnel_session.dart';

class _FakeHandle extends DocumentHandle {
  int closes = 0;

  @override
  String get title => 'fake.txt';

  @override
  Widget buildBody(BuildContext context) => const Text('body');

  @override
  Future<bool> confirmClose(BuildContext context) async => true;

  @override
  Future<void> close() async {
    closes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('refresh reloads the open document from the host',
      (tester) async {
    const file = RemoteFile(name: 'a.txt', path: '/p/a.txt', isDirectory: false);
    var created = 0;

    await tester.pumpWidget(MaterialApp(
      home: RemoteFileBrowserPage(
        session: FakeTunnelSession(),
        initialPath: '/p',
        projectRoot: '/p',
        hostId: 'h1',
        initialFile: file,
        documentHandleFactory: ({
          required TunnelSession session,
          required RemoteFile file,
          required String hostId,
          required String projectRoot,
          required String userScope,
        }) {
          created++;
          return _FakeHandle();
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(created, 1);

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刷新'));
    await tester.pumpAndSettle();

    expect(created, 2);
  });
}
