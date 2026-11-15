import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('auto blur keyboard defaults to true', () async {
    expect(await AppSettings().autoBlurKeyboard(), isTrue);
  });

  test('persists auto blur keyboard setting', () async {
    final settings = AppSettings();
    await settings.setAutoBlurKeyboard(false);

    expect(await settings.autoBlurKeyboard(), isFalse);
  });
}
