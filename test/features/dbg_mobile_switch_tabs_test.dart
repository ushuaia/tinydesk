import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/document_handle.dart';
import 'package:tinydesk/features/documents/remote_file_browser_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_tunnel_session.dart';

class _Session extends FakeTunnelSession {
  @override
  Future<List<RemoteFile>> listDirectory(String path) async {
    if (path == '/p') {
      return const [
        RemoteFile(name: 'a.txt', path: '/p/a.txt', isDirectory: false),
      ];
    }
    if (path == '/q') {
      return const [
        RemoteFile(name: 'b.txt', path: '/q/b.txt', isDirectory: false),
      ];
    }
    return const [];
  }
}

class _Handle extends DocumentHandle {
  _Handle(this.file);
  final RemoteFile file;
  int closes = 0;
  @override
  String get title => file.name;
  @override
  Widget buildBody(BuildContext context) => Text('body-${file.name}');
  @override
  Future<bool> confirmClose(BuildContext context) async => true;
  @override
  Future<void> close() async => closes++;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('mobile: switching with a document open', (tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: RemoteFileBrowserPage(
        session: _Session(),
        initialPath: '/p',
        projectRoot: '/q',
        hostId: 'h1',
        floating: true,
        documentHandleFactory: ({required session, required file, required hostId, required projectRoot, required userScope}) =>
            _Handle(file),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();
    debugPrint('after open body: ${find.text('body-a.txt').evaluate().length}');

    // Reopen the drawer via the toolbar toggle, then switch project.
    await tester.tap(find.byIcon(Icons.account_tree_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('root-button')));
    await tester.pumpAndSettle();
    final q = find.text('q');
    debugPrint('q in menu: ${q.evaluate().length}');
    if (q.evaluate().isNotEmpty) {
      await tester.tap(q);
      await tester.pumpAndSettle();
    }
    debugPrint('b.txt: ${find.text('b.txt').evaluate().length} | body-a: ${find.text('body-a.txt').evaluate().length}');
  });
}
