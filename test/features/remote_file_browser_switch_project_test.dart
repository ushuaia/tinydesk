import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/explorer_state_store.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/document_handle.dart';
import 'package:tinydesk/features/documents/remote_file_browser_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_tunnel_session.dart';

class _Handle extends DocumentHandle {
  _Handle(this.file, {required this.canClose});

  final RemoteFile file;
  final bool canClose;
  int closes = 0;

  @override
  bool get dirty => !canClose;

  @override
  String get title => file.name;

  @override
  Widget buildBody(BuildContext context) => Text('body-${file.name}');

  @override
  Future<bool> confirmClose(BuildContext context) async => canClose;

  @override
  Future<void> close() async {
    closes++;
  }
}

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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<List<_Handle>> pumpPage(
    WidgetTester tester, {
    required bool canClose,
  }) async {
    final handles = <_Handle>[];
    await tester.pumpWidget(MaterialApp(
      home: RemoteFileBrowserPage(
        session: _Session(),
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
        }) {
          final handle = _Handle(file, canClose: canClose);
          handles.add(handle);
          return handle;
        },
      ),
    ));
    await tester.pumpAndSettle();
    return handles;
  }

  testWidgets('switching projects closes the open documents', (tester) async {
    final handles = await pumpPage(tester, canClose: true);
    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();
    expect(find.text('body-a.txt'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('root-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('q'));
    await tester.pumpAndSettle();

    expect(handles.single.closes, 1);
    expect(find.text('body-a.txt'), findsNothing);
    final state = await ExplorerStateStore().load('h1');
    expect(state.selectedRoot, '/q');
    expect(state.currentPath, '/q');
  });

  testWidgets('a vetoed switch keeps the project and the documents',
      (tester) async {
    final handles = await pumpPage(tester, canClose: false);
    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('root-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('q'));
    await tester.pumpAndSettle();

    expect(handles.single.closes, 0);
    expect(find.text('body-a.txt'), findsOneWidget);
    final state = await ExplorerStateStore().load('h1');
    expect(state.selectedRoot, isNot('/q'));
  });
}
