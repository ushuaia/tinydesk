import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/document_handle.dart';
import 'package:tinydesk/features/documents/remote_file_browser_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_tunnel_session.dart';

class _SniffSession extends FakeTunnelSession {
  _SniffSession({required this.head}) : super(files: const [_dat, _bin]);

  final Uint8List head;

  @override
  Future<Uint8List> readHead(String path, int length) async => head;
}

const _dat = RemoteFile(name: 'notes.dat', path: '/p/notes.dat', isDirectory: false);
const _bin = RemoteFile(name: 'image.bin', path: '/p/image.bin', isDirectory: false);

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

  Future<int> open(
    WidgetTester tester,
    String name,
    Uint8List head,
  ) async {
    var created = 0;
    await tester.pumpWidget(MaterialApp(
      home: RemoteFileBrowserPage(
        session: _SniffSession(head: head),
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
        }) {
          created++;
          return _Handle(file);
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
    return created;
  }

  testWidgets('an unknown extension opens in the text viewer', (tester) async {
    final created = await open(
      tester,
      'notes.dat',
      Uint8List.fromList([104, 101, 108, 108, 111, 10]),
    );
    expect(created, 1);
    expect(find.text('body-notes.dat'), findsOneWidget);
  });

  testWidgets('binary content is refused with a hint', (tester) async {
    final created = await open(
      tester,
      'image.bin',
      Uint8List.fromList([137, 80, 78, 71, 0, 26, 10]),
    );
    expect(created, 0);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
