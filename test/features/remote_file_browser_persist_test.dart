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

/// Two-level listing: /p has one sub directory and one file; sub is empty.
class _DirSession extends FakeTunnelSession {
  _DirSession() : super(home: '/p');


  @override
  Future<List<RemoteFile>> listDirectory(String path) async {
    if (path == '/p') {
      return const [
        RemoteFile(name: 'sub', path: '/p/sub', isDirectory: true),
        RemoteFile(name: 'a.txt', path: '/p/a.txt', isDirectory: false),
      ];
    }
    return const [];
  }
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

  testWidgets('the floating window restores its pages too', (tester) async {
    const a = RemoteFile(name: 'a.txt', path: '/home/test/a.txt', isDirectory: false);
    const b = RemoteFile(name: 'b.txt', path: '/home/test/b.txt', isDirectory: false);

    Widget floating() => MaterialApp(
          home: RemoteFileBrowserPage(
            session: FakeTunnelSession(
              home: '/home/test',
              files: const [a, b],
            ),
            hostId: 'h1',
            floating: true,
            documentHandleFactory: ({
              required session,
              required file,
              required hostId,
              required projectRoot,
              required userScope,
            }) =>
                _TabHandle(file),
          ),
        );

    await tester.pumpWidget(floating());
    await tester.pumpAndSettle();
    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('b.txt'));
    await tester.pumpAndSettle();

    // Close the window (page destroyed), then reopen it.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(floating());
    await tester.pumpAndSettle();

    final state = await ExplorerStateStore().load('h1');
    expect(state.openDocPaths,
        ['/home/test/a.txt', '/home/test/b.txt']);
    expect(
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
      1,
    );
  });

  testWidgets('the browsed directory comes back on the next visit',
      (tester) async {
    Widget page() => MaterialApp(
          home: RemoteFileBrowserPage(
            session: _DirSession(),
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
        );

    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    // Browse into the sub directory (no file opened).
    await tester.tap(find.text('sub'));
    await tester.pumpAndSettle();
    expect(find.text('/p/sub'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    // The empty state shows the restored working directory.
    expect(find.text('/p/sub'), findsOneWidget);
  });
}
