// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get fontScale => 'Font scale';

  @override
  String get connectionSection => 'Connection';

  @override
  String get keepAlive => 'Keep alive in background';

  @override
  String get keepAliveSubtitle =>
      'Best effort to keep the SSH tunnel alive in the background';

  @override
  String get autoBlurKeyboard => 'Auto-hide keyboard when opening a session';

  @override
  String get autoBlurKeyboardSubtitle =>
      'Avoid popping up the keyboard when opening a session';

  @override
  String get backgroundTask => 'Long-running task';

  @override
  String get dataSection => 'Data';

  @override
  String get clearData => 'Clear data';

  @override
  String get clearDataSubtitle => 'Delete all hosts and keys';

  @override
  String get clearDataConfirmTitle => 'Clear data?';

  @override
  String get clearDataConfirmBody =>
      'All host configurations and keys will be deleted. This cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get clear => 'Clear';

  @override
  String get dataCleared => 'Data cleared';

  @override
  String clearFailed(String error) {
    return 'Clear failed: $error';
  }

  @override
  String get aboutSection => 'About';

  @override
  String get appName => 'TinyDesk';

  @override
  String get appVersion => 'v1.1.1';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'Follow system';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get languageUpdated => 'Language updated';
}
