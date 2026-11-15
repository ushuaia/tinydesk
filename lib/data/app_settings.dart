import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_language.dart';

class AppSettings {
  static const _autoBlurKeyboardKey = 'settings.autoBlurKeyboard';
  static const _languageKey = 'settings.language';

  Future<bool> autoBlurKeyboard() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBlurKeyboardKey) ?? true;
  }

  Future<void> setAutoBlurKeyboard(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBlurKeyboardKey, value);
  }

  Future<AppLanguage> language() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_languageKey);
    return AppLanguage.values
        .where((v) => v.name == stored)
        .firstOrNull ?? AppLanguage.system;
  }

  Future<void> setLanguage(AppLanguage value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, value.name);
  }
}
