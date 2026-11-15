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
    required VoidCallback onMinimize,
    required VoidCallback onClose,
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
        onMinimize: onMinimize,
        onClose: onClose,
      ),
    );
  }

  testWidgets('floating mode turns the back button into minimize',
      (tester) async {
    var minimized = 0;
    var closed = 0;
    await tester.pumpWidget(buildPage(
      onMinimize: () => minimized++,
      onClose: () => closed++,
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.remove), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    expect(minimized, 1);
    expect(closed, 0);
  });

  testWidgets('closing without a document calls onClose', (tester) async {
    var closed = 0;
    await tester.pumpWidget(buildPage(
      onMinimize: () {},
      onClose: () => closed++,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(closed, 1);
  });

  testWidgets('empty initial path falls back to the home directory',
      (tester) async {
    await tester.pumpWidget(buildPage(
      onMinimize: () {},
      onClose: () {},
      initialPath: '',
      projectRoot: '',
    ));
    await tester.pumpAndSettle();

    expect(find.text('test'), findsWidgets);
  });
}
