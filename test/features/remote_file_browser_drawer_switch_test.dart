import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/document_handle.dart';
import 'package:tinydesk/features/documents/explorer_tree.dart';
import 'package:tinydesk/features/documents/remote_file_browser_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_tunnel_session.dart';

class _Session extends FakeTunnelSession {
  @override
  Future<List<RemoteFile>> listDirectory(String path) async {
    if (path == '/p') {
      return const [
        RemoteFile(name: 'sub', path: '/p/sub', isDirectory: true),
        RemoteFile(name: 'a.txt', path: '/p/a.txt', isDirectory: false),
      ];
    }
    if (path == '/p/sub') {
      return const [
        RemoteFile(name: 'c.txt', path: '/p/sub/c.txt', isDirectory: false),
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

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RemoteFileBrowserPage(
        session: _Session(),
        initialPath: '/p',
        projectRoot: '/q',
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
  }

  testWidgets('closing and reopening the drawer keeps the chosen project',
      (tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pump(tester);
    expect(find.text('a.txt'), findsOneWidget);

    // Switch to the other project.
    await tester.tap(find.byKey(const ValueKey('root-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('q'));
    await tester.pumpAndSettle();
    expect(find.text('b.txt'), findsOneWidget);

    // Close the drawer, reopen it from the toolbar toggle.
    await tester.tap(find.byIcon(Icons.account_tree_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byType(ExplorerTree), findsNothing);

    await tester.tap(find.byIcon(Icons.account_tree_outlined).first);
    await tester.pumpAndSettle();

    // The rebuilt tree must stay on the project we switched to.
    expect(find.byType(ExplorerTree), findsOneWidget);
    expect(find.text('b.txt'), findsOneWidget);
    expect(find.text('a.txt'), findsNothing);
  });


  testWidgets('closing and reopening the drawer keeps a browsed sub directory',
      (tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pump(tester);
    await tester.tap(find.text('sub'));
    await tester.pumpAndSettle();
    expect(find.text('c.txt'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.account_tree_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byType(ExplorerTree), findsNothing);

    await tester.tap(find.byIcon(Icons.account_tree_outlined).first);
    await tester.pumpAndSettle();

    // The rebuilt tree re-expands the directory we were browsing.
    expect(find.text('c.txt'), findsOneWidget);
  });

  testWidgets('a fresh page reopens on the project chosen last time',
      (tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget fresh() => MaterialApp(
          home: RemoteFileBrowserPage(
            session: _Session(),
            projectRoot: '/q',
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
        );

    await tester.pumpWidget(fresh());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('root-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('q'));
    await tester.pumpAndSettle();
    expect(find.text('b.txt'), findsOneWidget);

    // The window (and its page state) goes away, then reopens.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(fresh());
    await tester.pumpAndSettle();

    expect(find.text('b.txt'), findsOneWidget);
    expect(find.text('a.txt'), findsNothing);
  });
}
