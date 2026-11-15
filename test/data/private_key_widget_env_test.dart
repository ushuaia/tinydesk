import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/private_key_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('save then read inside a widget test', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = PrivateKeyStore();

    await store.save('h1', 'KEY', null);
    final result = await store.read('h1');

    expect(result?.$1, 'KEY');
  });
}
