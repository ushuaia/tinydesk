import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/gen/app_localizations.dart';

enum AppLanguage { system, chinese, english }

/// Holds the chosen app language, persists it, and gives non-widget code
/// (controllers, session managers) access to the current translations
/// through [AppL10n.t] — those layers have no BuildContext.
class AppLanguageController extends ChangeNotifier {
  AppLanguageController() {
    _load();
  }

  static const _key = 'settings.language';
  AppLanguage _value = AppLanguage.system;

  AppLanguage get value => _value;

  /// The locale passed to MaterialApp; null means "follow the system".
  Locale? get locale => switch (_value) {
        AppLanguage.system => _systemLocale,
        AppLanguage.chinese => const Locale('zh'),
        AppLanguage.english => const Locale('en'),
      };

  Locale get _systemLocale =>
      WidgetsBinding.instance.platformDispatcher.locale.languageCode
              .startsWith('zh')
          ? const Locale('zh')
          : const Locale('en');

  Future<void> set(AppLanguage value) async {
    _value = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return;
    final match = AppLanguage.values.where((v) => v.name == stored).firstOrNull;
    if (match != null) {
      _value = match;
      notifyListeners();
    }
  }
}

/// Keeps the resolved localization instance reachable from layers without
/// a BuildContext. Updated by the app builder on every locale change.
class AppL10n {
  AppL10n._();

  static AppLocalizations? _current;
  static AppLocalizations _fallback = lookupAppLocalizations(const Locale('en'));

  static void update(AppLocalizations? value) {
    if (value != null) _current = value;
  }

  static void setFallbackLocale(Locale locale) {
    _fallback = lookupAppLocalizations(locale);
  }

  static AppLocalizations get t => _current ?? _fallback;
}
