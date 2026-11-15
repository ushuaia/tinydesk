import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const _autoBlurKeyboardKey = 'settings.autoBlurKeyboard';

  Future<bool> autoBlurKeyboard() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBlurKeyboardKey) ?? true;
  }

  Future<void> setAutoBlurKeyboard(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBlurKeyboardKey, value);
  }
}
