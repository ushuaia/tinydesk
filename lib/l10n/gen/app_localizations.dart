import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearanceSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSection;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @fontScale.
  ///
  /// In en, this message translates to:
  /// **'Font scale'**
  String get fontScale;

  /// No description provided for @connectionSection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connectionSection;

  /// No description provided for @keepAlive.
  ///
  /// In en, this message translates to:
  /// **'Keep alive in background'**
  String get keepAlive;

  /// No description provided for @keepAliveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Best effort to keep the SSH tunnel alive in the background'**
  String get keepAliveSubtitle;

  /// No description provided for @autoBlurKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Auto-hide keyboard when opening a session'**
  String get autoBlurKeyboard;

  /// No description provided for @autoBlurKeyboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Avoid popping up the keyboard when opening a session'**
  String get autoBlurKeyboardSubtitle;

  /// No description provided for @backgroundTask.
  ///
  /// In en, this message translates to:
  /// **'Long-running task'**
  String get backgroundTask;

  /// No description provided for @dataSection.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get dataSection;

  /// No description provided for @clearData.
  ///
  /// In en, this message translates to:
  /// **'Clear data'**
  String get clearData;

  /// No description provided for @clearDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all hosts and keys'**
  String get clearDataSubtitle;

  /// No description provided for @clearDataConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear data?'**
  String get clearDataConfirmTitle;

  /// No description provided for @clearDataConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'All host configurations and keys will be deleted. This cannot be undone.'**
  String get clearDataConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @dataCleared.
  ///
  /// In en, this message translates to:
  /// **'Data cleared'**
  String get dataCleared;

  /// No description provided for @clearFailed.
  ///
  /// In en, this message translates to:
  /// **'Clear failed: {error}'**
  String clearFailed(String error);

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSection;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'TinyDesk'**
  String get appName;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'v1.2.2'**
  String get appVersion;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @languageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Language updated'**
  String get languageUpdated;

  /// No description provided for @noHostsYet.
  ///
  /// In en, this message translates to:
  /// **'No hosts yet'**
  String get noHostsYet;

  /// No description provided for @addFirstHost.
  ///
  /// In en, this message translates to:
  /// **'Add your first host'**
  String get addFirstHost;

  /// No description provided for @emptyStateHint.
  ///
  /// In en, this message translates to:
  /// **'Add an SSH host to get started; on macOS you can also use the built-in This Machine.'**
  String get emptyStateHint;

  /// No description provided for @addHost.
  ///
  /// In en, this message translates to:
  /// **'Add host'**
  String get addHost;

  /// No description provided for @manualAdd.
  ///
  /// In en, this message translates to:
  /// **'Manual entry'**
  String get manualAdd;

  /// No description provided for @manualAddSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fill in the address and private key'**
  String get manualAddSubtitle;

  /// No description provided for @scanAdd.
  ///
  /// In en, this message translates to:
  /// **'Scan to add'**
  String get scanAdd;

  /// No description provided for @scanAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan to add a host'**
  String get scanAddTitle;

  /// No description provided for @scanAddSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import from a QR code on another device'**
  String get scanAddSubtitle;

  /// No description provided for @emptyStateTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote opencode workspace · tap a host to start'**
  String get emptyStateTitle;

  /// No description provided for @remoteHint.
  ///
  /// In en, this message translates to:
  /// **'Remote host: tap Add host, fill in the SSH address, port, username and key, save, then tap the card to connect.'**
  String get remoteHint;

  /// No description provided for @localFormHint.
  ///
  /// In en, this message translates to:
  /// **'This Machine: uses the local opencode service directly, no connection settings'**
  String get localFormHint;

  /// No description provided for @openHost.
  ///
  /// In en, this message translates to:
  /// **'Open host'**
  String get openHost;

  /// No description provided for @newTab.
  ///
  /// In en, this message translates to:
  /// **'New tab'**
  String get newTab;

  /// No description provided for @importHost.
  ///
  /// In en, this message translates to:
  /// **'Import host'**
  String get importHost;

  /// No description provided for @hostTab.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get hostTab;

  /// No description provided for @editHost.
  ///
  /// In en, this message translates to:
  /// **'Edit host'**
  String get editHost;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @exportKey.
  ///
  /// In en, this message translates to:
  /// **'Export private key'**
  String get exportKey;

  /// No description provided for @exportPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Export public key'**
  String get exportPublicKey;

  /// No description provided for @showHostQr.
  ///
  /// In en, this message translates to:
  /// **'Show host QR code'**
  String get showHostQr;

  /// No description provided for @localBadge.
  ///
  /// In en, this message translates to:
  /// **'Direct local · no SSH'**
  String get localBadge;

  /// No description provided for @hostDeleted.
  ///
  /// In en, this message translates to:
  /// **'This host has been deleted'**
  String get hostDeleted;

  /// No description provided for @favoritesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load favorites: {error}'**
  String favoritesLoadFailed(String error);

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorite files yet'**
  String get noFavorites;

  /// No description provided for @favoritesHint.
  ///
  /// In en, this message translates to:
  /// **'Open a file in the file page and tap ☆ to favorite it'**
  String get favoritesHint;

  /// No description provided for @clearFavorites.
  ///
  /// In en, this message translates to:
  /// **'Clear favorites'**
  String get clearFavorites;

  /// No description provided for @clearFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear favorites?'**
  String get clearFavoritesTitle;

  /// No description provided for @clearFavoritesBody.
  ///
  /// In en, this message translates to:
  /// **'Only the favorite records are removed; remote files are not deleted.'**
  String get clearFavoritesBody;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String loadFailed(String error);

  /// No description provided for @invalidPort.
  ///
  /// In en, this message translates to:
  /// **'Invalid port'**
  String get invalidPort;

  /// No description provided for @readFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read file: {error}'**
  String readFileFailed(String error);

  /// No description provided for @publicKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Public key copied'**
  String get publicKeyCopied;

  /// No description provided for @generateNewKey.
  ///
  /// In en, this message translates to:
  /// **'Generate new key'**
  String get generateNewKey;

  /// No description provided for @keyCommentHint.
  ///
  /// In en, this message translates to:
  /// **'The comment is stored in authorized_keys for later identification.'**
  String get keyCommentHint;

  /// No description provided for @keyComment.
  ///
  /// In en, this message translates to:
  /// **'Key comment'**
  String get keyComment;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @keyGeneratedCopied.
  ///
  /// In en, this message translates to:
  /// **'Key generated, public key copied'**
  String get keyGeneratedCopied;

  /// No description provided for @keyGenerated.
  ///
  /// In en, this message translates to:
  /// **'Key generated'**
  String get keyGenerated;

  /// No description provided for @generateKeyFailed.
  ///
  /// In en, this message translates to:
  /// **'Key generation failed: {error}'**
  String generateKeyFailed(String error);

  /// No description provided for @checkFormErrors.
  ///
  /// In en, this message translates to:
  /// **'Please fix the errors in the form'**
  String get checkFormErrors;

  /// No description provided for @unrecognizedKey.
  ///
  /// In en, this message translates to:
  /// **'Unrecognized key format — use OpenSSH format (.ppk is not supported)'**
  String get unrecognizedKey;

  /// No description provided for @keyUnrecognized.
  ///
  /// In en, this message translates to:
  /// **'Private key format not recognized'**
  String get keyUnrecognized;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailed(String error);

  /// No description provided for @nameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get nameOptional;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. dev box'**
  String get nameHint;

  /// No description provided for @hostAddress.
  ///
  /// In en, this message translates to:
  /// **'Host address'**
  String get hostAddress;

  /// No description provided for @hostAddressHint.
  ///
  /// In en, this message translates to:
  /// **'IP or domain'**
  String get hostAddressHint;

  /// No description provided for @enterHostAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter the host address'**
  String get enterHostAddress;

  /// No description provided for @sshPort.
  ///
  /// In en, this message translates to:
  /// **'SSH port'**
  String get sshPort;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @enterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter the username'**
  String get enterUsername;

  /// No description provided for @openSshKey.
  ///
  /// In en, this message translates to:
  /// **'OpenSSH private key'**
  String get openSshKey;

  /// No description provided for @keyKeepHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to keep the stored private key'**
  String get keyKeepHint;

  /// No description provided for @pasteKey.
  ///
  /// In en, this message translates to:
  /// **'Paste the OpenSSH private key'**
  String get pasteKey;

  /// No description provided for @importFromFile.
  ///
  /// In en, this message translates to:
  /// **'Import from file'**
  String get importFromFile;

  /// No description provided for @generateKey.
  ///
  /// In en, this message translates to:
  /// **'Generate key'**
  String get generateKey;

  /// No description provided for @publicKeyClipboard.
  ///
  /// In en, this message translates to:
  /// **'Public key (copied to clipboard)'**
  String get publicKeyClipboard;

  /// No description provided for @publicKeyUsage.
  ///
  /// In en, this message translates to:
  /// **'Append this public key to ~/.ssh/authorized_keys on the host'**
  String get publicKeyUsage;

  /// No description provided for @copyPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Copy public key'**
  String get copyPublicKey;

  /// No description provided for @passphraseOptional.
  ///
  /// In en, this message translates to:
  /// **'Key passphrase (optional)'**
  String get passphraseOptional;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @hostKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'Private key for this host not found'**
  String get hostKeyMissing;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailed;

  /// No description provided for @qrStep1.
  ///
  /// In en, this message translates to:
  /// **'On the target device tap Add host → Scan to add, then scan this first code.'**
  String get qrStep1;

  /// No description provided for @qrStep2.
  ///
  /// In en, this message translates to:
  /// **'Then scan this second code; the target device imports automatically.'**
  String get qrStep2;

  /// No description provided for @qrKeyWarning.
  ///
  /// In en, this message translates to:
  /// **'The code contains your private key and stops working as soon as this window closes.'**
  String get qrKeyWarning;

  /// No description provided for @copyContent.
  ///
  /// In en, this message translates to:
  /// **'Copy content'**
  String get copyContent;

  /// No description provided for @showStage2.
  ///
  /// In en, this message translates to:
  /// **'Scanned — show stage 2'**
  String get showStage2;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @qrPinHint.
  ///
  /// In en, this message translates to:
  /// **'On the other device open Import → Scan and enter the same PIN.'**
  String get qrPinHint;

  /// No description provided for @scanFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String scanFailedDetail(String error);

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String scanFailed(String error);

  /// No description provided for @noCameraFallback.
  ///
  /// In en, this message translates to:
  /// **'Camera scanning is not available here — copy the content on the exporting device and use paste import.'**
  String get noCameraFallback;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty'**
  String get clipboardEmpty;

  /// No description provided for @decrypting.
  ///
  /// In en, this message translates to:
  /// **'Decrypting and importing…'**
  String get decrypting;

  /// No description provided for @hostImported.
  ///
  /// In en, this message translates to:
  /// **'Host “{name}” imported'**
  String hostImported(String name);

  /// No description provided for @connectAndOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect and open?'**
  String get connectAndOpenTitle;

  /// No description provided for @connectAndOpenBody.
  ///
  /// In en, this message translates to:
  /// **'Connect to {name} first, then open this file.'**
  String connectAndOpenBody(String name);

  /// No description provided for @connectionNotReady.
  ///
  /// In en, this message translates to:
  /// **'Connection not ready'**
  String get connectionNotReady;

  /// No description provided for @noOpenSessions.
  ///
  /// In en, this message translates to:
  /// **'No open sessions'**
  String get noOpenSessions;

  /// No description provided for @unknownHost.
  ///
  /// In en, this message translates to:
  /// **'Unknown host'**
  String get unknownHost;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @connectionFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionFailedTitle;

  /// No description provided for @detectingOpencode.
  ///
  /// In en, this message translates to:
  /// **'Detecting opencode…'**
  String get detectingOpencode;

  /// No description provided for @establishingTunnel.
  ///
  /// In en, this message translates to:
  /// **'Establishing tunnel…'**
  String get establishingTunnel;

  /// No description provided for @pairing.
  ///
  /// In en, this message translates to:
  /// **'Pairing…'**
  String get pairing;

  /// No description provided for @openTerminalFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open terminal: {error}'**
  String openTerminalFailed(String error);

  /// No description provided for @openPdfFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open PDF: {error}'**
  String openPdfFailed(String error);

  /// No description provided for @pdfTooLarge.
  ///
  /// In en, this message translates to:
  /// **'PDF is over 100MB and cannot be opened in the app yet'**
  String get pdfTooLarge;

  /// No description provided for @disconnectedReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Connection lost, reconnecting…'**
  String get disconnectedReconnecting;

  /// No description provided for @networkReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Network lost, reconnecting…'**
  String get networkReconnecting;

  /// No description provided for @reconnectingWith.
  ///
  /// In en, this message translates to:
  /// **'{message} — reconnecting'**
  String reconnectingWith(String message);

  /// No description provided for @closeTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Close {name}?'**
  String closeTabTitle(String name);

  /// No description provided for @closeTabBody.
  ///
  /// In en, this message translates to:
  /// **'Its connection will be closed and its terminal terminated. Other hosts are unaffected.'**
  String get closeTabBody;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @quitTitle.
  ///
  /// In en, this message translates to:
  /// **'Quit TinyDesk?'**
  String get quitTitle;

  /// No description provided for @quitBody.
  ///
  /// In en, this message translates to:
  /// **'All session connections will be closed.'**
  String get quitBody;

  /// No description provided for @quit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get quit;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String connectionFailed(String error);

  /// No description provided for @opencodeVersion.
  ///
  /// In en, this message translates to:
  /// **'opencode version'**
  String get opencodeVersion;

  /// No description provided for @checkingVersions.
  ///
  /// In en, this message translates to:
  /// **'Fetching version info…'**
  String get checkingVersions;

  /// No description provided for @currentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get currentVersion;

  /// No description provided for @latestVersion.
  ///
  /// In en, this message translates to:
  /// **'Latest version'**
  String get latestVersion;

  /// No description provided for @upgrading.
  ///
  /// In en, this message translates to:
  /// **'Upgrading…'**
  String get upgrading;

  /// No description provided for @upgradeDone.
  ///
  /// In en, this message translates to:
  /// **'Upgrade finished. If the opencode service was running it has been restarted.'**
  String get upgradeDone;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get operationFailed;

  /// No description provided for @latestUnknown.
  ///
  /// In en, this message translates to:
  /// **'Latest version unavailable (the host cannot reach the npm registry)'**
  String get latestUnknown;

  /// No description provided for @alreadyUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Already up to date'**
  String get alreadyUpToDate;

  /// No description provided for @versionReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read the opencode version: {error}'**
  String versionReadFailed(String error);

  /// No description provided for @upgradeFailed.
  ///
  /// In en, this message translates to:
  /// **'Upgrade failed: {error}'**
  String upgradeFailed(String error);

  /// No description provided for @opencodeUpgrade.
  ///
  /// In en, this message translates to:
  /// **'opencode upgrade'**
  String get opencodeUpgrade;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @quickStartHostsHint.
  ///
  /// In en, this message translates to:
  /// **'This Machine: on macOS no SSH is needed — tap the This Machine card and the opencode service is discovered and started automatically.\nRemote host: tap Add host, fill in the SSH address, port, username and key, save, then tap the card to connect.'**
  String get quickStartHostsHint;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparing;

  /// No description provided for @sshConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting over SSH…'**
  String get sshConnecting;

  /// No description provided for @verifyingKey.
  ///
  /// In en, this message translates to:
  /// **'Verifying key…'**
  String get verifyingKey;

  /// No description provided for @startingOpencodeService.
  ///
  /// In en, this message translates to:
  /// **'Starting the opencode service…'**
  String get startingOpencodeService;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get reconnecting;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @closeTerminal.
  ///
  /// In en, this message translates to:
  /// **'Close terminal'**
  String get closeTerminal;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// No description provided for @terminalTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} · Terminal'**
  String terminalTitle(String name);

  /// No description provided for @terminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// No description provided for @openingTerminal.
  ///
  /// In en, this message translates to:
  /// **'Opening terminal…'**
  String get openingTerminal;

  /// No description provided for @terminalDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Terminal disconnected'**
  String get terminalDisconnected;

  /// No description provided for @terminalError.
  ///
  /// In en, this message translates to:
  /// **'Terminal error'**
  String get terminalError;

  /// No description provided for @connectionClosedBanner.
  ///
  /// In en, this message translates to:
  /// **'[Connection closed]'**
  String get connectionClosedBanner;

  /// No description provided for @connectionResumedBanner.
  ///
  /// In en, this message translates to:
  /// **'[Connection restored — reopening the terminal…]'**
  String get connectionResumedBanner;

  /// No description provided for @taskIdle.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get taskIdle;

  /// No description provided for @taskRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get taskRunning;

  /// No description provided for @taskStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get taskStopped;

  /// No description provided for @filesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get filesTitle;

  /// No description provided for @scanButton.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanButton;

  /// No description provided for @terminalErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'Terminal error: {error}'**
  String terminalErrorDetail(String error);

  /// No description provided for @docReloaded.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" was updated on the server and reloaded'**
  String docReloaded(String name);

  /// No description provided for @docConflict.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" was changed on the server and you have unsaved edits — save first, then refresh manually'**
  String docConflict(String name);

  /// No description provided for @unsavedChangesFile.
  ///
  /// In en, this message translates to:
  /// **'{name} has unsaved changes.'**
  String unsavedChangesFile(String name);

  /// No description provided for @unsavedChangesFileW.
  ///
  /// In en, this message translates to:
  /// **'{name} has unsaved changes.'**
  String unsavedChangesFileW(String name);

  /// No description provided for @pdfTooLarge100.
  ///
  /// In en, this message translates to:
  /// **'PDF is over 100MB and cannot be opened in the app yet'**
  String get pdfTooLarge100;

  /// No description provided for @selectFromTree.
  ///
  /// In en, this message translates to:
  /// **'Pick a file from the directory tree'**
  String get selectFromTree;

  /// No description provided for @overwriteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Saving will overwrite the newer content on the server. Continue?'**
  String get overwriteConfirm;

  /// No description provided for @overwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get overwrite;

  /// No description provided for @fileChangedRemotely.
  ///
  /// In en, this message translates to:
  /// **'The file was modified remotely'**
  String get fileChangedRemotely;

  /// No description provided for @remoteStateUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot check the server copy'**
  String get remoteStateUnknownTitle;

  /// No description provided for @remoteStateUnknown.
  ///
  /// In en, this message translates to:
  /// **'TinyDesk could not read the file on the server, so saving now may overwrite changes made elsewhere. Continue?'**
  String get remoteStateUnknown;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedChanges;

  /// No description provided for @editorNotReady.
  ///
  /// In en, this message translates to:
  /// **'Editor not ready'**
  String get editorNotReady;

  /// No description provided for @jumpToPathTitle.
  ///
  /// In en, this message translates to:
  /// **'Jump to path'**
  String get jumpToPathTitle;

  /// No description provided for @jumpToPath.
  ///
  /// In en, this message translates to:
  /// **'Jump to path…'**
  String get jumpToPath;

  /// No description provided for @jump.
  ///
  /// In en, this message translates to:
  /// **'Jump'**
  String get jump;

  /// No description provided for @pathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied'**
  String get pathCopied;

  /// No description provided for @copyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get copyPath;

  /// No description provided for @copyCommand.
  ///
  /// In en, this message translates to:
  /// **'Copy command'**
  String get copyCommand;

  /// No description provided for @commandCopied.
  ///
  /// In en, this message translates to:
  /// **'Command copied'**
  String get commandCopied;

  /// No description provided for @fileExists.
  ///
  /// In en, this message translates to:
  /// **'A file with the same name already exists'**
  String get fileExists;

  /// No description provided for @nameNoSlash.
  ///
  /// In en, this message translates to:
  /// **'Name cannot contain \"/\"'**
  String get nameNoSlash;

  /// No description provided for @folderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderName;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get fileName;

  /// No description provided for @fileNameNoSlash.
  ///
  /// In en, this message translates to:
  /// **'File name cannot contain \"/\"'**
  String get fileNameNoSlash;

  /// No description provided for @newFile.
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get newFile;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createFailed.
  ///
  /// In en, this message translates to:
  /// **'Creation failed: {error}'**
  String createFailed(String error);

  /// No description provided for @fileCreated.
  ///
  /// In en, this message translates to:
  /// **'Created {name}'**
  String fileCreated(String name);

  /// No description provided for @folderCreated.
  ///
  /// In en, this message translates to:
  /// **'Created {name}/'**
  String folderCreated(String name);

  /// No description provided for @deleteFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteFileTitle(String name);

  /// No description provided for @fileDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {name}'**
  String fileDeleted(String name);

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailed(String error);

  /// No description provided for @deleteIrreversible.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get deleteIrreversible;

  /// No description provided for @openTree.
  ///
  /// In en, this message translates to:
  /// **'Open directory tree'**
  String get openTree;

  /// No description provided for @collapseTree.
  ///
  /// In en, this message translates to:
  /// **'Collapse directory tree'**
  String get collapseTree;

  /// No description provided for @showHiddenFiles.
  ///
  /// In en, this message translates to:
  /// **'Show hidden files'**
  String get showHiddenFiles;

  /// No description provided for @hideHiddenFiles.
  ///
  /// In en, this message translates to:
  /// **'Hide hidden files'**
  String get hideHiddenFiles;

  /// No description provided for @expandTree.
  ///
  /// In en, this message translates to:
  /// **'Expand directory tree'**
  String get expandTree;

  /// No description provided for @directoryTree.
  ///
  /// In en, this message translates to:
  /// **'Directory tree'**
  String get directoryTree;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// No description provided for @unfavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove favorite'**
  String get unfavorite;

  /// No description provided for @favorited.
  ///
  /// In en, this message translates to:
  /// **'Favorited'**
  String get favorited;

  /// No description provided for @unfavorited.
  ///
  /// In en, this message translates to:
  /// **'Favorite removed'**
  String get unfavorited;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String downloadFailed(String error);

  /// No description provided for @downloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled'**
  String get downloadCancelled;

  /// No description provided for @copyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy failed: {error}'**
  String copyFailed(String error);

  /// No description provided for @savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String savedTo(String path);

  /// No description provided for @unsupportedFile.
  ///
  /// In en, this message translates to:
  /// **'Opening .{extension} files is not supported yet'**
  String unsupportedFile(String extension);

  /// No description provided for @nonUtf8.
  ///
  /// In en, this message translates to:
  /// **'Not UTF-8 encoded — opened read-only'**
  String get nonUtf8;

  /// No description provided for @binaryContent.
  ///
  /// In en, this message translates to:
  /// **'Binary content detected, cannot edit'**
  String get binaryContent;

  /// No description provided for @fileTooLarge2MB.
  ///
  /// In en, this message translates to:
  /// **'File is over 2MB — opened read-only'**
  String get fileTooLarge2MB;

  /// No description provided for @fileTooLarge5MB.
  ///
  /// In en, this message translates to:
  /// **'File is over 5MB and cannot be opened in the app yet'**
  String get fileTooLarge5MB;

  /// No description provided for @notEditable.
  ///
  /// In en, this message translates to:
  /// **'This file cannot be edited'**
  String get notEditable;

  /// No description provided for @thisMachine.
  ///
  /// In en, this message translates to:
  /// **'This Machine'**
  String get thisMachine;

  /// No description provided for @quickStart.
  ///
  /// In en, this message translates to:
  /// **'Quick start'**
  String get quickStart;

  /// No description provided for @step1Prepare.
  ///
  /// In en, this message translates to:
  /// **'① Before connecting'**
  String get step1Prepare;

  /// No description provided for @step2Open.
  ///
  /// In en, this message translates to:
  /// **'② Open a session'**
  String get step2Open;

  /// No description provided for @step3Switch.
  ///
  /// In en, this message translates to:
  /// **'③ Switch and close'**
  String get step3Switch;

  /// No description provided for @step4Toolbar.
  ///
  /// In en, this message translates to:
  /// **'④ Toolbar'**
  String get step4Toolbar;

  /// No description provided for @tabHint.
  ///
  /// In en, this message translates to:
  /// **'Top tabs switch between open hosts; the × in a tab closes only that host session. Closing the last tab returns here — tap + to open a new host anytime.'**
  String get tabHint;

  /// No description provided for @toolbarTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal: the shell of the current host (local terminal not supported yet).'**
  String get toolbarTerminal;

  /// No description provided for @serviceStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start the opencode service: {error}'**
  String serviceStartFailed(String error);

  /// No description provided for @serviceStartFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed to start the opencode service: {status}'**
  String serviceStartFailedStatus(String status);

  /// No description provided for @localServiceStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start the local opencode service: {error}'**
  String localServiceStartFailed(String error);

  /// No description provided for @localServiceUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The local opencode service is not responding — start it and try again'**
  String get localServiceUnreachable;

  /// No description provided for @hostOpencodeMissing.
  ///
  /// In en, this message translates to:
  /// **'opencode is not installed on the host — install it and try again'**
  String get hostOpencodeMissing;

  /// No description provided for @localOpencodeMissing.
  ///
  /// In en, this message translates to:
  /// **'opencode is not installed on this machine — install it and try again'**
  String get localOpencodeMissing;

  /// No description provided for @remoteOpencodeUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The remote opencode service is not responding — start it and try again'**
  String get remoteOpencodeUnreachable;

  /// No description provided for @connectionTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The server did not respond in time — check the network and try again'**
  String get connectionTimedOut;

  /// No description provided for @opencodeCommandFailed.
  ///
  /// In en, this message translates to:
  /// **'opencode command failed'**
  String get opencodeCommandFailed;

  /// No description provided for @cannotReachHost.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach {host}:{port} — check the network'**
  String cannotReachHost(String host, String port);

  /// No description provided for @sshConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'SSH connection failed: {error}'**
  String sshConnectFailed(String error);

  /// No description provided for @localPortBusy.
  ///
  /// In en, this message translates to:
  /// **'Local port {port} is busy — pick another'**
  String localPortBusy(String port);

  /// No description provided for @pairingFailed.
  ///
  /// In en, this message translates to:
  /// **'Pairing failed: {error}'**
  String pairingFailed(String error);

  /// No description provided for @pairingFailedHttp.
  ///
  /// In en, this message translates to:
  /// **'Pairing failed (HTTP {code})'**
  String pairingFailedHttp(String code);

  /// No description provided for @redeemFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to redeem the pairing link: {error}'**
  String redeemFailed(String error);

  /// No description provided for @parsePairFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not parse the pairing link: {output}'**
  String parsePairFailed(String output);

  /// No description provided for @parsePairFailedRaw.
  ///
  /// In en, this message translates to:
  /// **'Could not parse the pairing link: {output}'**
  String parsePairFailedRaw(String output);

  /// No description provided for @pairingNoCookie.
  ///
  /// In en, this message translates to:
  /// **'The pairing link returned no session cookie (HTTP {code})'**
  String pairingNoCookie(String code);

  /// No description provided for @parseCookieFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not parse the session cookie'**
  String get parseCookieFailed;

  /// No description provided for @createPairFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create the pairing link: {error}'**
  String createPairFailed(String error);

  /// No description provided for @commandFailedCode.
  ///
  /// In en, this message translates to:
  /// **'Command failed (exit code {code}): {command}'**
  String commandFailedCode(String code, String command);

  /// No description provided for @commandFailedCodeOnly.
  ///
  /// In en, this message translates to:
  /// **'Command failed (exit code {code})'**
  String commandFailedCodeOnly(String code);

  /// No description provided for @parseVersionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not parse the opencode version output'**
  String get parseVersionFailed;

  /// No description provided for @opencodeNotFound.
  ///
  /// In en, this message translates to:
  /// **'opencode not found — the login-shell PATH and common install paths were checked'**
  String get opencodeNotFound;

  /// No description provided for @portFieldInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid port field'**
  String get portFieldInvalid;

  /// No description provided for @hostKeyVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Host key verification failed'**
  String get hostKeyVerificationFailed;

  /// No description provided for @cannotReadDirectory.
  ///
  /// In en, this message translates to:
  /// **'Cannot read directory'**
  String get cannotReadDirectory;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied: allow TinyDesk in System Settings → Privacy & Security → Files and Folders'**
  String get permissionDenied;

  /// No description provided for @toolbarFiles.
  ///
  /// In en, this message translates to:
  /// **'Files: browse the host directory, open md / pdf / csv / xlsx / docx.'**
  String get toolbarFiles;

  /// No description provided for @toolbarDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents: recently opened documents, continue where you left off.'**
  String get toolbarDocuments;

  /// No description provided for @filesTitleW.
  ///
  /// In en, this message translates to:
  /// **'{name} · Files'**
  String filesTitleW(String name);

  /// No description provided for @installHint.
  ///
  /// In en, this message translates to:
  /// **'Run opencode --version after installing — it should print 2.x. Older versions can be upgraded with opencode upgrade --major. On Windows, use WSL.'**
  String get installHint;

  /// No description provided for @saveFailedSimple.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get saveFailedSimple;

  /// No description provided for @openFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file: {error}'**
  String openFileFailed(String error);

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of 2'**
  String stepOf(String step);

  /// No description provided for @disconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect {name}?'**
  String disconnectTitle(String name);

  /// No description provided for @disconnectShort.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectShort;

  /// No description provided for @qrStage1Waiting.
  ///
  /// In en, this message translates to:
  /// **'QR code 1 · waiting'**
  String get qrStage1Waiting;

  /// No description provided for @qrStage2Waiting.
  ///
  /// In en, this message translates to:
  /// **'QR code 2 · waiting'**
  String get qrStage2Waiting;

  /// No description provided for @qrFormatUnrecognized.
  ///
  /// In en, this message translates to:
  /// **'QR format not recognized'**
  String get qrFormatUnrecognized;

  /// No description provided for @qrContent.
  ///
  /// In en, this message translates to:
  /// **'QR content'**
  String get qrContent;

  /// No description provided for @qrIncomplete.
  ///
  /// In en, this message translates to:
  /// **'QR content incomplete'**
  String get qrIncomplete;

  /// No description provided for @qrUnreadable.
  ///
  /// In en, this message translates to:
  /// **'QR content unreadable'**
  String get qrUnreadable;

  /// No description provided for @qrMissingId.
  ///
  /// In en, this message translates to:
  /// **'QR code is missing the transfer id'**
  String get qrMissingId;

  /// No description provided for @qrDecryptFailed.
  ///
  /// In en, this message translates to:
  /// **'QR code could not be decrypted'**
  String get qrDecryptFailed;

  /// No description provided for @qrExpired.
  ///
  /// In en, this message translates to:
  /// **'The QR code has expired — export it again on the source device'**
  String get qrExpired;

  /// No description provided for @qrNoHost.
  ///
  /// In en, this message translates to:
  /// **'No host in the QR code'**
  String get qrNoHost;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @fangchitai.
  ///
  /// In en, this message translates to:
  /// **'TinyDesk'**
  String get fangchitai;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomInFont.
  ///
  /// In en, this message translates to:
  /// **'Larger text'**
  String get zoomInFont;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @copyPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Copy private key'**
  String get copyPrivateKey;

  /// No description provided for @exportKeyPassphrase.
  ///
  /// In en, this message translates to:
  /// **'This key has a passphrase; the original is still required after export.'**
  String get exportKeyPassphrase;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @publicKeyAuthKeys.
  ///
  /// In en, this message translates to:
  /// **'The public key can be added to ~/.ssh/authorized_keys on the host.'**
  String get publicKeyAuthKeys;

  /// No description provided for @closeWindow.
  ///
  /// In en, this message translates to:
  /// **'Close window'**
  String get closeWindow;

  /// No description provided for @closeFile.
  ///
  /// In en, this message translates to:
  /// **'Close file'**
  String get closeFile;

  /// No description provided for @closeFilePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Close the file page?'**
  String get closeFilePageTitle;

  /// No description provided for @needOtherStage.
  ///
  /// In en, this message translates to:
  /// **'Scan the other code to complete the transfer'**
  String get needOtherStage;

  /// No description provided for @tunnelFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to establish the SSH tunnel: {error}'**
  String tunnelFailed(String error);

  /// No description provided for @closeFilePageBody.
  ///
  /// In en, this message translates to:
  /// **'You will return to the session page. Saved files are safe.'**
  String get closeFilePageBody;

  /// No description provided for @acceptCode.
  ///
  /// In en, this message translates to:
  /// **'Accept this code'**
  String get acceptCode;

  /// No description provided for @fileNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. notes.md'**
  String get fileNameHint;

  /// No description provided for @qrMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two codes do not match — export again'**
  String get qrMismatch;

  /// No description provided for @keyRejected.
  ///
  /// In en, this message translates to:
  /// **'Key rejected — check that the public key is on the host'**
  String get keyRejected;

  /// No description provided for @targetNeedsV2.
  ///
  /// In en, this message translates to:
  /// **'The target host must have opencode V2. TinyDesk is its remote UI — sessions, files and terminal all come from opencode on that host.'**
  String get targetNeedsV2;

  /// No description provided for @contentCopied.
  ///
  /// In en, this message translates to:
  /// **'Content copied'**
  String get contentCopied;

  /// No description provided for @toggleEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to switch editing: {error}'**
  String toggleEditFailed(String error);

  /// No description provided for @switchedToTab.
  ///
  /// In en, this message translates to:
  /// **'Switched to {name}'**
  String switchedToTab(String name);

  /// No description provided for @missingHostFields.
  ///
  /// In en, this message translates to:
  /// **'Missing host fields'**
  String get missingHostFields;

  /// No description provided for @deleteHostTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteHostTitle(String name);

  /// No description provided for @upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// No description provided for @generatePublicKeyFailed.
  ///
  /// In en, this message translates to:
  /// **'Public key generation failed: {error}'**
  String generatePublicKeyFailed(String error);

  /// No description provided for @keyIsPassword.
  ///
  /// In en, this message translates to:
  /// **'The private key is as sensitive as your password — do not share it.'**
  String get keyIsPassword;

  /// No description provided for @privateKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Private key copied'**
  String get privateKeyCopied;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @zoomOutFont.
  ///
  /// In en, this message translates to:
  /// **'Smaller text'**
  String get zoomOutFont;

  /// No description provided for @fileTooLarge50MB.
  ///
  /// In en, this message translates to:
  /// **'File is over 50MB and cannot be opened in the app yet'**
  String get fileTooLarge50MB;

  /// No description provided for @folderDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'The folder and everything inside it will be deleted. This cannot be undone.'**
  String get folderDeleteWarning;

  /// No description provided for @parseKeyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not parse the private key'**
  String get parseKeyFailed;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reading;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @connectingHost.
  ///
  /// In en, this message translates to:
  /// **'Connecting to host…'**
  String get connectingHost;

  /// No description provided for @readOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get readOnly;

  /// No description provided for @hostQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Host QR code'**
  String get hostQrTitle;

  /// No description provided for @deleteHostBody.
  ///
  /// In en, this message translates to:
  /// **'The host configuration and its saved private key will be deleted.'**
  String get deleteHostBody;

  /// No description provided for @pasteImportHint.
  ///
  /// In en, this message translates to:
  /// **'On desktop, copy on the exporting device and paste here'**
  String get pasteImportHint;

  /// No description provided for @pasteImportNoCamera.
  ///
  /// In en, this message translates to:
  /// **'Desktop has no camera — copy each code on the exporting device and paste them one by one.'**
  String get pasteImportNoCamera;

  /// No description provided for @viewerLoadFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Load failed: '**
  String get viewerLoadFailedPrefix;

  /// No description provided for @viewerLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get viewerLoading;

  /// No description provided for @viewerUnsupportedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Unsupported format: '**
  String get viewerUnsupportedPrefix;

  /// No description provided for @viewerLoadingPdf.
  ///
  /// In en, this message translates to:
  /// **'Loading PDF…'**
  String get viewerLoadingPdf;

  /// No description provided for @viewerPdfLoadFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'PDF load failed: '**
  String get viewerPdfLoadFailedPrefix;

  /// No description provided for @connectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost — tap retry'**
  String get connectionLost;

  /// No description provided for @pageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The page failed to load — tap retry'**
  String get pageLoadFailed;

  /// No description provided for @pairingLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'The sign-in link expired — tap retry'**
  String get pairingLinkExpired;

  /// No description provided for @exportDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Export diagnostics'**
  String get exportDiagnostics;

  /// No description provided for @exportDiagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save the recent app log for troubleshooting'**
  String get exportDiagnosticsSubtitle;

  /// No description provided for @exportDiagnosticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No diagnostics recorded yet'**
  String get exportDiagnosticsEmpty;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @terminalSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Find in terminal'**
  String get terminalSearchHint;

  /// No description provided for @terminalFontSize.
  ///
  /// In en, this message translates to:
  /// **'Terminal font size'**
  String get terminalFontSize;

  /// No description provided for @newTerminalTab.
  ///
  /// In en, this message translates to:
  /// **'New terminal tab'**
  String get newTerminalTab;

  /// No description provided for @closeTerminalTab.
  ///
  /// In en, this message translates to:
  /// **'Close terminal tab'**
  String get closeTerminalTab;

  /// No description provided for @terminalTabName.
  ///
  /// In en, this message translates to:
  /// **'Terminal {n}'**
  String terminalTabName(int n);

  /// No description provided for @renameTerminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename terminal tab'**
  String get renameTerminalTitle;

  /// No description provided for @renameTerminalSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get renameTerminalSave;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
