import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/core/app_session_manager.dart';
import 'package:tinydesk/core/session_scope.dart';
import 'package:tinydesk/data/host.dart';
import 'package:tinydesk/data/host_repository.dart';
import 'package:tinydesk/data/host_store.dart';
import 'package:tinydesk/data/private_key_store.dart';
import 'package:tinydesk/features/hosts/host_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Host buildHost() => Host(
      id: 'h1',
      name: 'dev box',
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

  Widget wrap(Widget child) {
    final session = AppSessionManager();
    addTearDown(session.dispose);
    return SessionScope(
      manager: session,
      child: MaterialApp(home: child),
    );
  }

  testWidgets('shows empty state from repository', (tester) async {
    final repo = HostRepository(SharedPreferencesHostStore());

    await tester.pumpWidget(
      wrap(
        HostListScreen(
          repository: repo,
          keyStore: PrivateKeyStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有主机'), findsOneWidget);
  });

  testWidgets('opens host form from add button', (tester) async {
    final repo = HostRepository(SharedPreferencesHostStore());

    await tester.pumpWidget(
      wrap(
        HostListScreen(
          repository: repo,
          keyStore: PrivateKeyStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('手动添加'), findsOneWidget);
    expect(find.text('扫码添加'), findsOneWidget);

    await tester.tap(find.text('手动添加'));
    await tester.pumpAndSettle();

    expect(find.text('主机地址'), findsOneWidget);
  });

  testWidgets('exports private key to clipboard', (tester) async {
    final repo = HostRepository(SharedPreferencesHostStore());
    final keyStore = PrivateKeyStore();
    final host = buildHost();
    await repo.upsert(host);
    await keyStore.save(host.id, 'PRIVATE KEY', null);

    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      wrap(
        HostListScreen(
          repository: repo,
          keyStore: keyStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出私钥'));
    await tester.pumpAndSettle();

    expect(find.text('私钥等同于主机密码，请勿泄露。'), findsOneWidget);
    expect(find.textContaining('PRIVATE KEY'), findsOneWidget);

    await tester.tap(find.text('复制私钥'));
    await tester.pumpAndSettle();

    expect(copied, 'PRIVATE KEY');
    expect(find.text('私钥已复制'), findsOneWidget);
  });
}
