import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/host.dart';
import 'package:tinydesk/data/host_repository.dart';
import 'package:tinydesk/data/host_store.dart';
import 'package:tinydesk/data/private_key_store.dart';
import 'package:tinydesk/data/secret_store.dart';
import 'package:tinydesk/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Host _host(String id) => Host(
      id: id,
      name: id,
      host: '10.0.0.2',
      port: 22,
      username: 'me',
      remotePort: 49374,
      localPort: 49375,
      autoStartServer: false,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildPage({
    HostRepository? repository,
    PrivateKeyStore? keyStore,
  }) {
    return MaterialApp(
      home: SettingsPage(
        repository: repository ?? HostRepository(SharedPreferencesHostStore()),
        keyStore: keyStore ??
            PrivateKeyStore(const SharedPreferencesSecretStore()),
      ),
    );
  }

  testWidgets('shows appearance settings', (tester) async {
    await tester.pumpWidget(buildPage());

    expect(find.text('深色模式'), findsOneWidget);
    expect(find.text('字体缩放'), findsOneWidget);
  });

  testWidgets('shows data section', (tester) async {
    await tester.pumpWidget(buildPage());

    expect(find.text('清除数据'), findsOneWidget);
  });

  testWidgets('shows auto blur keyboard setting', (tester) async {
    await tester.pumpWidget(buildPage());

    expect(find.text('进入会话时自动收起键盘'), findsOneWidget);
  });

  testWidgets('shows background task status', (tester) async {
    await tester.pumpWidget(buildPage());

    expect(find.text('长时任务'), findsOneWidget);
  });

  testWidgets('shows the current app name and version', (tester) async {
    await tester.pumpWidget(buildPage());

    expect(find.text('方寸台 TinyDesk'), findsOneWidget);
    expect(find.text('v1.1.1'), findsOneWidget);
  });

  testWidgets('clear data really removes hosts and keys', (tester) async {
    final repository = HostRepository(SharedPreferencesHostStore());
    await repository.upsert(_host('h1'));
    final keyStore = PrivateKeyStore(const SharedPreferencesSecretStore());
    await keyStore.save('h1', 'PRIVATE KEY', 'pass');

    await tester.pumpWidget(
      buildPage(repository: repository, keyStore: keyStore),
    );
    await tester.pumpAndSettle();

    final clearTile = find.widgetWithText(ListTile, '清除数据');
    await tester.ensureVisible(clearTile);
    await tester.pumpAndSettle();
    await tester.tap(clearTile);
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '清除'));
    await tester.pumpAndSettle();

    expect(await repository.all(), isEmpty);
    expect(await keyStore.read('h1'), isNull);
  });
}
