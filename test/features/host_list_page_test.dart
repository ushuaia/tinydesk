import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/host.dart';
import 'package:tinydesk/features/hosts/host_list_page.dart';

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
  testWidgets('shows empty state with add button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HostListPage(hosts: [])),
    );

    expect(find.text('No hosts yet'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('shows host name and user@host', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HostListPage(hosts: [buildHost()])),
    );

    expect(find.text('dev box'), findsOneWidget);
    expect(find.text('me@10.0.0.2'), findsOneWidget);
  });

  testWidgets('shows export private key menu action', (tester) async {
    Host? exported;
    await tester.pumpWidget(
      MaterialApp(
        home: HostListPage(
          hosts: [buildHost()],
          onExportKey: (host) => exported = host,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Export private key'), findsOneWidget);

    await tester.tap(find.text('Export private key'));
    await tester.pumpAndSettle();
    expect(exported?.id, 'h1');
  });

  testWidgets('shows edit and delete menu actions', (tester) async {
    Host? edited;
    Host? deleted;
    await tester.pumpWidget(
      MaterialApp(
        home: HostListPage(
          hosts: [buildHost()],
          onEdit: (host) => edited = host,
          onDelete: (host) => deleted = host,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(edited?.id, 'h1');

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted?.id, 'h1');
  });

}
