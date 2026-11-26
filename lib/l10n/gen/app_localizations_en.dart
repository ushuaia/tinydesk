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
  String get appVersion => 'v1.2.2';

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

  @override
  String get noHostsYet => 'No hosts yet';

  @override
  String get addFirstHost => 'Add your first host';

  @override
  String get emptyStateHint =>
      'Add an SSH host to get started; on macOS you can also use the built-in This Machine.';

  @override
  String get addHost => 'Add host';

  @override
  String get manualAdd => 'Manual entry';

  @override
  String get manualAddSubtitle => 'Fill in the address and private key';

  @override
  String get scanAdd => 'Scan to add';

  @override
  String get scanAddTitle => 'Scan to add a host';

  @override
  String get scanAddSubtitle => 'Import from a QR code on another device';

  @override
  String get emptyStateTitle =>
      'Remote opencode workspace · tap a host to start';

  @override
  String get remoteHint =>
      'Remote host: tap Add host, fill in the SSH address, port, username and key, save, then tap the card to connect.';

  @override
  String get localFormHint =>
      'This Machine: uses the local opencode service directly, no connection settings';

  @override
  String get openHost => 'Open host';

  @override
  String get newTab => 'New tab';

  @override
  String get importHost => 'Import host';

  @override
  String get hostTab => 'Host';

  @override
  String get editHost => 'Edit host';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get exportKey => 'Export private key';

  @override
  String get exportPublicKey => 'Export public key';

  @override
  String get showHostQr => 'Show host QR code';

  @override
  String get localBadge => 'Direct local · no SSH';

  @override
  String get hostDeleted => 'This host has been deleted';

  @override
  String favoritesLoadFailed(String error) {
    return 'Failed to load favorites: $error';
  }

  @override
  String get noFavorites => 'No favorite files yet';

  @override
  String get favoritesHint =>
      'Open a file in the file page and tap ☆ to favorite it';

  @override
  String get clearFavorites => 'Clear favorites';

  @override
  String get clearFavoritesTitle => 'Clear favorites?';

  @override
  String get clearFavoritesBody =>
      'Only the favorite records are removed; remote files are not deleted.';

  @override
  String get refresh => 'Refresh';

  @override
  String loadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get invalidPort => 'Invalid port';

  @override
  String readFileFailed(String error) {
    return 'Failed to read file: $error';
  }

  @override
  String get publicKeyCopied => 'Public key copied';

  @override
  String get generateNewKey => 'Generate new key';

  @override
  String get keyCommentHint =>
      'The comment is stored in authorized_keys for later identification.';

  @override
  String get keyComment => 'Key comment';

  @override
  String get generate => 'Generate';

  @override
  String get keyGeneratedCopied => 'Key generated, public key copied';

  @override
  String get keyGenerated => 'Key generated';

  @override
  String generateKeyFailed(String error) {
    return 'Key generation failed: $error';
  }

  @override
  String get checkFormErrors => 'Please fix the errors in the form';

  @override
  String get unrecognizedKey =>
      'Unrecognized key format — use OpenSSH format (.ppk is not supported)';

  @override
  String get keyUnrecognized => 'Private key format not recognized';

  @override
  String saveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get nameOptional => 'Name (optional)';

  @override
  String get nameHint => 'e.g. dev box';

  @override
  String get hostAddress => 'Host address';

  @override
  String get hostAddressHint => 'IP or domain';

  @override
  String get enterHostAddress => 'Enter the host address';

  @override
  String get sshPort => 'SSH port';

  @override
  String get username => 'Username';

  @override
  String get enterUsername => 'Enter the username';

  @override
  String get openSshKey => 'OpenSSH private key';

  @override
  String get keyKeepHint => 'Leave empty to keep the stored private key';

  @override
  String get pasteKey => 'Paste the OpenSSH private key';

  @override
  String get importFromFile => 'Import from file';

  @override
  String get generateKey => 'Generate key';

  @override
  String get publicKeyClipboard => 'Public key (copied to clipboard)';

  @override
  String get publicKeyUsage =>
      'Append this public key to ~/.ssh/authorized_keys on the host';

  @override
  String get copyPublicKey => 'Copy public key';

  @override
  String get passphraseOptional => 'Key passphrase (optional)';

  @override
  String get saving => 'Saving…';

  @override
  String get save => 'Save';

  @override
  String get hostKeyMissing => 'Private key for this host not found';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get qrStep1 =>
      'On the target device tap Add host → Scan to add, then scan this first code.';

  @override
  String get qrStep2 =>
      'Then scan this second code; the target device imports automatically.';

  @override
  String get qrKeyWarning =>
      'The code contains your private key and stops working as soon as this window closes.';

  @override
  String get copyContent => 'Copy content';

  @override
  String get showStage2 => 'Scanned — show stage 2';

  @override
  String get done => 'Done';

  @override
  String get qrPinHint =>
      'On the other device open Import → Scan and enter the same PIN.';

  @override
  String scanFailedDetail(String error) {
    return 'Scan failed: $error';
  }

  @override
  String scanFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get noCameraFallback =>
      'Camera scanning is not available here — copy the content on the exporting device and use paste import.';

  @override
  String get clipboardEmpty => 'Clipboard is empty';

  @override
  String get decrypting => 'Decrypting and importing…';

  @override
  String hostImported(String name) {
    return 'Host “$name” imported';
  }

  @override
  String get connectAndOpenTitle => 'Connect and open?';

  @override
  String connectAndOpenBody(String name) {
    return 'Connect to $name first, then open this file.';
  }

  @override
  String get connectionNotReady => 'Connection not ready';

  @override
  String get noOpenSessions => 'No open sessions';

  @override
  String get unknownHost => 'Unknown host';

  @override
  String get retry => 'Retry';

  @override
  String get connectionFailedTitle => 'Connection failed';

  @override
  String get detectingOpencode => 'Detecting opencode…';

  @override
  String get establishingTunnel => 'Establishing tunnel…';

  @override
  String get pairing => 'Pairing…';

  @override
  String openTerminalFailed(String error) {
    return 'Failed to open terminal: $error';
  }

  @override
  String openPdfFailed(String error) {
    return 'Failed to open PDF: $error';
  }

  @override
  String get pdfTooLarge =>
      'PDF is over 100MB and cannot be opened in the app yet';

  @override
  String get disconnectedReconnecting => 'Connection lost, reconnecting…';

  @override
  String get networkReconnecting => 'Network lost, reconnecting…';

  @override
  String reconnectingWith(String message) {
    return '$message — reconnecting';
  }

  @override
  String closeTabTitle(String name) {
    return 'Close $name?';
  }

  @override
  String get closeTabBody =>
      'Its connection will be closed and its terminal terminated. Other hosts are unaffected.';

  @override
  String get close => 'Close';

  @override
  String get quitTitle => 'Quit TinyDesk?';

  @override
  String get quitBody => 'All session connections will be closed.';

  @override
  String get quit => 'Quit';

  @override
  String connectionFailed(String error) {
    return 'Connection failed: $error';
  }

  @override
  String get opencodeVersion => 'opencode version';

  @override
  String get checkingVersions => 'Fetching version info…';

  @override
  String get currentVersion => 'Current version';

  @override
  String get latestVersion => 'Latest version';

  @override
  String get upgrading => 'Upgrading…';

  @override
  String get upgradeDone =>
      'Upgrade finished. If the opencode service was running it has been restarted.';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get latestUnknown =>
      'Latest version unavailable (the host cannot reach the npm registry)';

  @override
  String get alreadyUpToDate => 'Already up to date';

  @override
  String versionReadFailed(String error) {
    return 'Failed to read the opencode version: $error';
  }

  @override
  String upgradeFailed(String error) {
    return 'Upgrade failed: $error';
  }

  @override
  String get opencodeUpgrade => 'opencode upgrade';

  @override
  String get continueLabel => 'Continue';

  @override
  String get quickStartHostsHint =>
      'This Machine: on macOS no SSH is needed — tap the This Machine card and the opencode service is discovered and started automatically.\nRemote host: tap Add host, fill in the SSH address, port, username and key, save, then tap the card to connect.';

  @override
  String get preparing => 'Preparing';

  @override
  String get sshConnecting => 'Connecting over SSH…';

  @override
  String get verifyingKey => 'Verifying key…';

  @override
  String get startingOpencodeService => 'Starting the opencode service…';

  @override
  String get connected => 'Connected';

  @override
  String get reconnecting => 'Reconnecting…';

  @override
  String get minimize => 'Minimize';

  @override
  String get closeTerminal => 'Close terminal';

  @override
  String get reconnect => 'Reconnect';

  @override
  String terminalTitle(String name) {
    return '$name · Terminal';
  }

  @override
  String get terminal => 'Terminal';

  @override
  String get openingTerminal => 'Opening terminal…';

  @override
  String get terminalDisconnected => 'Terminal disconnected';

  @override
  String get terminalError => 'Terminal error';

  @override
  String get connectionClosedBanner => '[Connection closed]';

  @override
  String get connectionResumedBanner =>
      '[Connection restored — reopening the terminal…]';

  @override
  String get taskIdle => 'Not started';

  @override
  String get taskRunning => 'Running';

  @override
  String get taskStopped => 'Stopped';

  @override
  String get filesTitle => 'Files';

  @override
  String get scanButton => 'Scan';

  @override
  String terminalErrorDetail(String error) {
    return 'Terminal error: $error';
  }

  @override
  String docReloaded(String name) {
    return '\"$name\" was updated on the server and reloaded';
  }

  @override
  String docConflict(String name) {
    return '\"$name\" was changed on the server and you have unsaved edits — save first, then refresh manually';
  }

  @override
  String unsavedChangesFile(String name) {
    return '$name has unsaved changes.';
  }

  @override
  String unsavedChangesFileW(String name) {
    return '$name has unsaved changes.';
  }

  @override
  String get pdfTooLarge100 =>
      'PDF is over 100MB and cannot be opened in the app yet';

  @override
  String get selectFromTree => 'Pick a file from the directory tree';

  @override
  String get overwriteConfirm =>
      'Saving will overwrite the newer content on the server. Continue?';

  @override
  String get overwrite => 'Overwrite';

  @override
  String get fileChangedRemotely => 'The file was modified remotely';

  @override
  String get remoteStateUnknownTitle => 'Cannot check the server copy';

  @override
  String get remoteStateUnknown =>
      'TinyDesk could not read the file on the server, so saving now may overwrite changes made elsewhere. Continue?';

  @override
  String get unsavedChanges => 'Unsaved changes';

  @override
  String get editorNotReady => 'Editor not ready';

  @override
  String get jumpToPathTitle => 'Jump to path';

  @override
  String get jumpToPath => 'Jump to path…';

  @override
  String get jump => 'Jump';

  @override
  String get pathCopied => 'Path copied';

  @override
  String get copyPath => 'Copy path';

  @override
  String get copyCommand => 'Copy command';

  @override
  String get commandCopied => 'Command copied';

  @override
  String get fileExists => 'A file with the same name already exists';

  @override
  String get nameNoSlash => 'Name cannot contain \"/\"';

  @override
  String get folderName => 'Folder name';

  @override
  String get fileName => 'File name';

  @override
  String get fileNameNoSlash => 'File name cannot contain \"/\"';

  @override
  String get newFile => 'New file';

  @override
  String get newFolder => 'New folder';

  @override
  String get create => 'Create';

  @override
  String createFailed(String error) {
    return 'Creation failed: $error';
  }

  @override
  String fileCreated(String name) {
    return 'Created $name';
  }

  @override
  String folderCreated(String name) {
    return 'Created $name/';
  }

  @override
  String deleteFileTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String fileDeleted(String name) {
    return 'Deleted $name';
  }

  @override
  String deleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get deleteIrreversible => 'This cannot be undone.';

  @override
  String get openTree => 'Open directory tree';

  @override
  String get collapseTree => 'Collapse directory tree';

  @override
  String get showHiddenFiles => 'Show hidden files';

  @override
  String get hideHiddenFiles => 'Hide hidden files';

  @override
  String get expandTree => 'Expand directory tree';

  @override
  String get directoryTree => 'Directory tree';

  @override
  String get favorite => 'Favorite';

  @override
  String get unfavorite => 'Remove favorite';

  @override
  String get favorited => 'Favorited';

  @override
  String get unfavorited => 'Favorite removed';

  @override
  String get clearAll => 'Clear all';

  @override
  String get loading => 'Loading…';

  @override
  String get actions => 'Actions';

  @override
  String get open => 'Open';

  @override
  String get download => 'Download';

  @override
  String downloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get downloadCancelled => 'Download cancelled';

  @override
  String copyFailed(String error) {
    return 'Copy failed: $error';
  }

  @override
  String savedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String unsupportedFile(String extension) {
    return 'Opening .$extension files is not supported yet';
  }

  @override
  String get nonUtf8 => 'Not UTF-8 encoded — opened read-only';

  @override
  String get binaryContent => 'Binary content detected, cannot edit';

  @override
  String get fileTooLarge2MB => 'File is over 2MB — opened read-only';

  @override
  String get fileTooLarge5MB =>
      'File is over 5MB and cannot be opened in the app yet';

  @override
  String get notEditable => 'This file cannot be edited';

  @override
  String get thisMachine => 'This Machine';

  @override
  String get quickStart => 'Quick start';

  @override
  String get step1Prepare => '① Before connecting';

  @override
  String get step2Open => '② Open a session';

  @override
  String get step3Switch => '③ Switch and close';

  @override
  String get step4Toolbar => '④ Toolbar';

  @override
  String get tabHint =>
      'Top tabs switch between open hosts; the × in a tab closes only that host session. Closing the last tab returns here — tap + to open a new host anytime.';

  @override
  String get toolbarTerminal =>
      'Terminal: the shell of the current host (local terminal not supported yet).';

  @override
  String serviceStartFailed(String error) {
    return 'Failed to start the opencode service: $error';
  }

  @override
  String serviceStartFailedStatus(String status) {
    return 'Failed to start the opencode service: $status';
  }

  @override
  String localServiceStartFailed(String error) {
    return 'Failed to start the local opencode service: $error';
  }

  @override
  String get localServiceUnreachable =>
      'The local opencode service is not responding — start it and try again';

  @override
  String get hostOpencodeMissing =>
      'opencode is not installed on the host — install it and try again';

  @override
  String get localOpencodeMissing =>
      'opencode is not installed on this machine — install it and try again';

  @override
  String get remoteOpencodeUnreachable =>
      'The remote opencode service is not responding — start it and try again';

  @override
  String get connectionTimedOut =>
      'The server did not respond in time — check the network and try again';

  @override
  String get opencodeCommandFailed => 'opencode command failed';

  @override
  String cannotReachHost(String host, String port) {
    return 'Cannot reach $host:$port — check the network';
  }

  @override
  String sshConnectFailed(String error) {
    return 'SSH connection failed: $error';
  }

  @override
  String localPortBusy(String port) {
    return 'Local port $port is busy — pick another';
  }

  @override
  String pairingFailed(String error) {
    return 'Pairing failed: $error';
  }

  @override
  String pairingFailedHttp(String code) {
    return 'Pairing failed (HTTP $code)';
  }

  @override
  String redeemFailed(String error) {
    return 'Failed to redeem the pairing link: $error';
  }

  @override
  String parsePairFailed(String output) {
    return 'Could not parse the pairing link: $output';
  }

  @override
  String parsePairFailedRaw(String output) {
    return 'Could not parse the pairing link: $output';
  }

  @override
  String pairingNoCookie(String code) {
    return 'The pairing link returned no session cookie (HTTP $code)';
  }

  @override
  String get parseCookieFailed => 'Could not parse the session cookie';

  @override
  String createPairFailed(String error) {
    return 'Failed to create the pairing link: $error';
  }

  @override
  String commandFailedCode(String code, String command) {
    return 'Command failed (exit code $code): $command';
  }

  @override
  String commandFailedCodeOnly(String code) {
    return 'Command failed (exit code $code)';
  }

  @override
  String get parseVersionFailed =>
      'Could not parse the opencode version output';

  @override
  String get opencodeNotFound =>
      'opencode not found — the login-shell PATH and common install paths were checked';

  @override
  String get portFieldInvalid => 'Invalid port field';

  @override
  String get hostKeyVerificationFailed => 'Host key verification failed';

  @override
  String get cannotReadDirectory => 'Cannot read directory';

  @override
  String get permissionDenied =>
      'Access denied: allow TinyDesk in System Settings → Privacy & Security → Files and Folders';

  @override
  String get toolbarFiles =>
      'Files: browse the host directory, open md / pdf / csv / xlsx / docx.';

  @override
  String get toolbarDocuments =>
      'Documents: recently opened documents, continue where you left off.';

  @override
  String filesTitleW(String name) {
    return '$name · Files';
  }

  @override
  String get installHint =>
      'Run opencode --version after installing — it should print 2.x. Older versions can be upgraded with opencode upgrade --major. On Windows, use WSL.';

  @override
  String get saveFailedSimple => 'Save failed';

  @override
  String openFileFailed(String error) {
    return 'Failed to open file: $error';
  }

  @override
  String stepOf(String step) {
    return 'Step $step of 2';
  }

  @override
  String disconnectTitle(String name) {
    return 'Disconnect $name?';
  }

  @override
  String get disconnectShort => 'Disconnect';

  @override
  String get qrStage1Waiting => 'QR code 1 · waiting';

  @override
  String get qrStage2Waiting => 'QR code 2 · waiting';

  @override
  String get qrFormatUnrecognized => 'QR format not recognized';

  @override
  String get qrContent => 'QR content';

  @override
  String get qrIncomplete => 'QR content incomplete';

  @override
  String get qrUnreadable => 'QR content unreadable';

  @override
  String get qrMissingId => 'QR code is missing the transfer id';

  @override
  String get qrDecryptFailed => 'QR code could not be decrypted';

  @override
  String get qrExpired =>
      'The QR code has expired — export it again on the source device';

  @override
  String get qrNoHost => 'No host in the QR code';

  @override
  String get back => 'Back';

  @override
  String get fangchitai => 'TinyDesk';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomInFont => 'Larger text';

  @override
  String get discard => 'Discard';

  @override
  String get copyPrivateKey => 'Copy private key';

  @override
  String get exportKeyPassphrase =>
      'This key has a passphrase; the original is still required after export.';

  @override
  String get more => 'More';

  @override
  String get publicKeyAuthKeys =>
      'The public key can be added to ~/.ssh/authorized_keys on the host.';

  @override
  String get closeWindow => 'Close window';

  @override
  String get closeFile => 'Close file';

  @override
  String get closeFilePageTitle => 'Close the file page?';

  @override
  String get needOtherStage => 'Scan the other code to complete the transfer';

  @override
  String tunnelFailed(String error) {
    return 'Failed to establish the SSH tunnel: $error';
  }

  @override
  String get closeFilePageBody =>
      'You will return to the session page. Saved files are safe.';

  @override
  String get acceptCode => 'Accept this code';

  @override
  String get fileNameHint => 'e.g. notes.md';

  @override
  String get qrMismatch => 'The two codes do not match — export again';

  @override
  String get keyRejected =>
      'Key rejected — check that the public key is on the host';

  @override
  String get targetNeedsV2 =>
      'The target host must have opencode V2. TinyDesk is its remote UI — sessions, files and terminal all come from opencode on that host.';

  @override
  String get contentCopied => 'Content copied';

  @override
  String toggleEditFailed(String error) {
    return 'Failed to switch editing: $error';
  }

  @override
  String switchedToTab(String name) {
    return 'Switched to $name';
  }

  @override
  String get missingHostFields => 'Missing host fields';

  @override
  String deleteHostTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get upgrade => 'Upgrade';

  @override
  String generatePublicKeyFailed(String error) {
    return 'Public key generation failed: $error';
  }

  @override
  String get keyIsPassword =>
      'The private key is as sensitive as your password — do not share it.';

  @override
  String get privateKeyCopied => 'Private key copied';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get zoomOutFont => 'Smaller text';

  @override
  String get fileTooLarge50MB =>
      'File is over 50MB and cannot be opened in the app yet';

  @override
  String get folderDeleteWarning =>
      'The folder and everything inside it will be deleted. This cannot be undone.';

  @override
  String get parseKeyFailed => 'Could not parse the private key';

  @override
  String get saved => 'Saved';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get reading => 'Reading';

  @override
  String get paste => 'Paste';

  @override
  String get connectingHost => 'Connecting to host…';

  @override
  String get readOnly => 'Read-only';

  @override
  String get hostQrTitle => 'Host QR code';

  @override
  String get deleteHostBody =>
      'The host configuration and its saved private key will be deleted.';

  @override
  String get pasteImportHint =>
      'On desktop, copy on the exporting device and paste here';

  @override
  String get pasteImportNoCamera =>
      'Desktop has no camera — copy each code on the exporting device and paste them one by one.';

  @override
  String get viewerLoadFailedPrefix => 'Load failed: ';

  @override
  String get viewerLoading => 'Loading…';

  @override
  String get viewerUnsupportedPrefix => 'Unsupported format: ';

  @override
  String get viewerLoadingPdf => 'Loading PDF…';

  @override
  String get viewerPdfLoadFailedPrefix => 'PDF load failed: ';

  @override
  String get connectionLost => 'Connection lost — tap retry';

  @override
  String get pageLoadFailed => 'The page failed to load — tap retry';

  @override
  String get pairingLinkExpired => 'The sign-in link expired — tap retry';

  @override
  String get exportDiagnostics => 'Export diagnostics';

  @override
  String get exportDiagnosticsSubtitle =>
      'Save the recent app log for troubleshooting';

  @override
  String get exportDiagnosticsEmpty => 'No diagnostics recorded yet';

  @override
  String get copy => 'Copy';

  @override
  String get terminalSearchHint => 'Find in terminal';

  @override
  String get terminalFontSize => 'Terminal font size';

  @override
  String get newTerminalTab => 'New terminal tab';

  @override
  String get closeTerminalTab => 'Close terminal tab';

  @override
  String terminalTabName(int n) {
    return 'Terminal $n';
  }

  @override
  String get renameTerminalTitle => 'Rename terminal tab';

  @override
  String get renameTerminalSave => 'Save';
}
