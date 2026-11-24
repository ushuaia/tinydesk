import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/features/documents/remote_file_browser_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_tunnel_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildPage({
    String initialPath = '/home/test',
    String projectRoot = '/home/test',
  }) {
    return MaterialApp(
      home: RemoteFileBrowserPage(
        session: FakeTunnelSession(),
        initialPath: initialPath,
        projectRoot: projectRoot,
        hostId: 'h1',
        floating: true,
      ),
    );
  }

  testWidgets('floating header leaves window chrome to the traffic lights',
      (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    // The macOS traffic lights own minimize/close; the in-window header must
    // not duplicate them.
    expect(find.byIcon(Icons.remove), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('empty initial path falls back to the home directory',
      (tester) async {
    await tester.pumpWidget(buildPage(
      initialPath: '',
      projectRoot: '',
    ));
    await tester.pumpAndSettle();

    expect(find.text('test'), findsWidgets);
  });
}
