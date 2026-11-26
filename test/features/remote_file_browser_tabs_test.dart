import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/document_handle.dart';
import 'package:tinydesk/features/documents/remote_file_browser_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_tunnel_session.dart';

class _TabHandle extends DocumentHandle {
  _TabHandle(this.file);

  final RemoteFile file;
  int closes = 0;

  @override
  String get title => file.name;

  @override
  Widget buildBody(BuildContext context) => Text('body-${file.name}');

  @override
  Future<bool> confirmClose(BuildContext context) async => true;

  @override
  Future<void> close() async {
    closes++;
  }
}

RemoteFile _file(String name) =>
    RemoteFile(name: name, path: '/p/$name', isDirectory: false);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RemoteFileBrowserPage(
        session: FakeTunnelSession(
          files: [_file('a.txt'), _file('b.txt')],
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
  }

  testWidgets('each opened file gets its own tab and keeps its state',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('b.txt'));
    await tester.pumpAndSettle();

    // The tree shows both names; the content area stacked both bodies.
    final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.index, 1);
    expect(find.text('body-a.txt', skipOffstage: false), findsOneWidget);
    expect(find.text('body-b.txt'), findsOneWidget);

    // Clicking the first tab chip brings it back.
    await tester.tap(find.text('a.txt').last);
    await tester.pumpAndSettle();
    final stackAfter = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stackAfter.index, 0);
  });

  testWidgets('closing the active tab falls back to the neighbour',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('b.txt'));
    await tester.pumpAndSettle();

    // The app bar ✕ closes the visible document.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.index, 0);
    expect(find.text('body-b.txt'), findsNothing);
    expect(find.text('body-a.txt', skipOffstage: false), findsOneWidget);
  });
}
