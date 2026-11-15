import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/workspace_state_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves and restores the last URL per host', () async {
    final store = WorkspaceStateStore();
    expect(await store.loadUrl('h1'), isNull);

    await store.saveUrl('h1', 'http://127.0.0.1:49375/session/abc');
    await store.saveUrl('h2', 'http://127.0.0.1:49376/');

    expect(
      await store.loadUrl('h1'),
      'http://127.0.0.1:49375/session/abc',
    );
    expect(await store.loadUrl('h2'), 'http://127.0.0.1:49376/');

    await store.clearUrl('h1');
    expect(await store.loadUrl('h1'), isNull);
    expect(await store.loadUrl('h2'), 'http://127.0.0.1:49376/');
  });
}
