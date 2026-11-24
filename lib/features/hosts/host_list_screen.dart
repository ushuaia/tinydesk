import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';


import 'package:flutter/services.dart';

import '../../session/session_scope.dart';
import '../../core/app_language.dart';
import '../../data/host.dart';
import '../../data/host_repository.dart';
import '../../data/port_allocator.dart';
import '../../data/private_key_store.dart';
import '../../data/favorite_store.dart';
import '../../platform/web_data.dart';
import '../settings/settings_page.dart';
import '../workspace/workspace_screen.dart';
import 'host_export_dialog.dart';
import 'host_form_page.dart';
import 'host_import_dialog.dart';
import 'host_scan_page.dart';
import 'host_list_page.dart';

class HostListScreen extends StatefulWidget {
  const HostListScreen({
    super.key,
    required this.repository,
    required this.keyStore,
    required this.language,
    this.popOnOpen = false,
    this.embedded = false,
    this.onHostOpened,
  });

  final HostRepository repository;
  final PrivateKeyStore keyStore;
  final AppLanguageController language;

  /// When true this page acts as the session launcher opened from the
  /// workspace: tapping a host opens/activates its session and returns.
  final bool popOnOpen;

  /// Rendered inside the workspace body (no app bar).
  final bool embedded;

  /// Embedded mode: called after a host session was opened/activated so
  /// the workspace can switch back to the session views.
  final VoidCallback? onHostOpened;

  @override
  State<HostListScreen> createState() => _HostListScreenState();
}

class _HostListScreenState extends State<HostListScreen> {
  late Future<List<Host>> _hosts;
  final FavoriteIndex _favorites = FavoriteIndex();
  final WebData _webData = const WebData();

  @override
  void initState() {
    super.initState();
    _hosts = widget.repository.all();
  }

  void _reload() {
    setState(() {
      _hosts = widget.repository.all();
    });
  }

  Future<void> _openForm({Host? host}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HostFormPage(
          repository: widget.repository,
          keyStore: widget.keyStore,
          initialHost: host,
          onSaved: (_) => _reload(),
        ),
      ),
    );
  }

  /// The add button offers manual entry and QR transfer side by side.
  Future<void> _openAddMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(AppL10n.t.manualAdd),
              subtitle: Text(AppL10n.t.manualAddSubtitle),
              onTap: () => Navigator.pop(sheetContext, 'manual'),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: Text(AppL10n.t.scanAdd),
              subtitle: Text(AppL10n.t.scanAddSubtitle),
              onTap: () => Navigator.pop(sheetContext, 'scan'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'manual') {
      _openForm();
    } else if (choice == 'scan') {
      unawaited(_openImport());
    }
  }

  void _openSettings() {
    final session = SessionScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          repository: widget.repository,
          keyStore: widget.keyStore,
          manager: session,
          language: widget.language,
        ),
      ),
    );
  }

  bool get _cameraScanSupported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.operatingSystem == 'ohos';

  /// Import via camera on Android/iOS, the Scan Kit plugin on HarmonyOS,
  /// and paste on desktop platforms.
  Future<List<String>?> _scanQr() async {
    if (Platform.isAndroid || Platform.isIOS) {
      // One camera session collects both codes: recreating the camera for
      // the second scan crashes mobile_scanner on iOS.
      return Navigator.of(context).push<List<String>>(
        MaterialPageRoute(
          builder: (_) => const HostScanPage(expected: 2),
        ),
      );
    }
    if (Platform.isMacOS || Platform.operatingSystem == 'ohos') {
      try {
        // The system scanner hosts its own page: opening it twice in a row
        // trips over the page transition on HarmonyOS, so scan one code per
        // tap and let the dialog guide the second one (it shows 1/2 progress).
        final text = await const MethodChannel('opencode/hostscan')
            .invokeMethod<String>('scan');
        if (text == null || text.isEmpty) return null;
        return [text];
      } on MissingPluginException {
        return null;
      } on PlatformException catch (error) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.t.scanFailedDetail((error.message ?? error.code).toString()))),
        );
        return null;
      }
    }
    return null;
  }

  Future<void> _openImport() async {
    final imported = await showDialog<Host>(
      context: context,
      builder: (_) => HostImportDialog(
        repository: widget.repository,
        keyStore: widget.keyStore,
        scanner: _cameraScanSupported ? _scanQr : null,
      ),
    );
    if (imported != null && mounted) _reload();
  }

  Future<void> _exportQr(Host host) async {
    if (host.isLocal) return;
    await showDialog<void>(
      context: context,
      builder: (_) => HostExportQrDialog(
        host: host,
        keyStore: widget.keyStore,
      ),
    );
  }

  Future<void> _deleteHost(Host host) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppL10n.t.deleteHostTitle(host.name)),
        content: Text(AppL10n.t.deleteHostBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL10n.t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppL10n.t.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.keyStore.delete(host.id);
    await widget.repository.delete(host.id);
    await _favorites.removeForHost(host.id);
    await _webData.clearCookies();
    if (mounted) _reload();
  }

  /// Ensures the host owns a distinct local tunnel port. opencode names its
  /// session cookie after that port, so a shared port would make two hosts
  /// fight over the same cookie name.
  Future<Host> _resolveLocalPort(Host host) async {
    final hosts = await widget.repository.all();
    final others = hosts.where((h) => h.id != host.id).toList();
    if (!others.any((h) => h.localPort == host.localPort)) return host;
    final port = const PortAllocator().nextAvailable(others);
    final updated = host.copyWith(localPort: port);
    await widget.repository.upsert(updated);
    return updated;
  }

  Future<void> _openHost(Host host) async {
    final session = SessionScope.of(context);

    final resolved = await _resolveLocalPort(host);
    if (!mounted) return;

    (String, String?)? key;
    if (!resolved.isLocal) {
      key = await widget.keyStore.read(resolved.id);
      if (!mounted) return;
      if (key == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.t.hostKeyMissing)),
        );
        return;
      }
    }
    // Multi-session: opening another host keeps every existing connection
    // and terminal alive — no switching confirmation needed.
    await session.openHost(
      resolved,
      key?.$1 ?? '',
      passphrase: key?.$2,
    );
    if (!mounted) return;
    if (widget.onHostOpened != null) {
      // Embedded launcher: switch the workspace back to the session views.
      widget.onHostOpened!();
      return;
    }
    if (widget.popOnOpen) {
      // Launcher mode: return to the workspace, which now shows this
      // host's tab (openHost activated it).
      Navigator.of(context).pop();
      return;
    }
    // Single workspace route: the host list stays the root page and the
    // workspace is replaced rather than stacked on every open.
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => WorkspaceScreen(
          session: session,
          language: widget.language,
          initialHostId: resolved.id,
          repository: widget.repository,
          keyStore: widget.keyStore,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  Future<void> _disconnect(Host host) async {
    final session = SessionScope.of(context);
    if (!session.hasSession(host.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppL10n.t.disconnectTitle(host.name)),
        content: Text(AppL10n.t.closeTabBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL10n.t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppL10n.t.disconnectShort),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await session.closeSession(host.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.disconnected)),
      );
    }
  }

  Future<void> _exportKey(Host host) async {
    final key = await widget.keyStore.read(host.id);
    if (!mounted) return;
    if (key == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.hostKeyMissing)),
      );
      return;
    }

    final privateKey = key.$1;
    final hasPassphrase = key.$2 != null && key.$2!.isNotEmpty;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppL10n.t.exportKey),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppL10n.t.keyIsPassword),
              if (hasPassphrase) ...[
                const SizedBox(height: 8),
                Text(AppL10n.t.exportKeyPassphrase),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(maxHeight: 240),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    privateKey,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppL10n.t.cancel),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: privateKey));
              } catch (error) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(AppL10n.t.copyFailed(error.toString()))),
                  );
                }
                return;
              }
              if (!mounted) return;
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(content: Text(AppL10n.t.privateKeyCopied)),
              );
            },
            child: Text(AppL10n.t.copyPrivateKey),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPublicKey(Host host) async {
    final key = await widget.keyStore.read(host.id);
    if (!mounted) return;
    if (key == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.hostKeyMissing)),
      );
      return;
    }

    String publicKey;
    try {
      final pairs = SSHKeyPair.fromPem(key.$1, key.$2);
      if (pairs.isEmpty) {
        throw FormatException(AppL10n.t.parseKeyFailed);
      }
      final encoded = pairs.first.toPublicKey().encode();
      final type = SSHHostKey.getType(encoded);
      final hostName = host.host.trim();
      final comment = 'tinydesk@${hostName.isEmpty ? 'host' : hostName}';
      publicKey = '$type ${base64Encode(encoded)} $comment';
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.t.generatePublicKeyFailed(error.toString()))),
        );
      }
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppL10n.t.exportPublicKey),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppL10n.t.publicKeyAuthKeys),
              const SizedBox(height: 12),
              Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(maxHeight: 240),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    publicKey,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppL10n.t.cancel),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: publicKey));
              } catch (error) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(AppL10n.t.copyFailed(error.toString()))),
                  );
                }
                return;
              }
              if (!mounted) return;
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(content: Text(AppL10n.t.publicKeyCopied)),
              );
            },
            child: Text(AppL10n.t.copyPublicKey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return FutureBuilder<List<Host>>(
      future: _hosts,
      builder: (context, snapshot) {
        // Built-in 本机 always first; Dart sort is stable so the
        // remaining hosts keep their stored order.
        final hosts = [...snapshot.data ?? const <Host>[]]..sort(
            (a, b) => (b.isLocal ? 1 : 0) - (a.isLocal ? 1 : 0),
          );
        return HostListPage(
          hosts: hosts,
          activeHostId: session.activeHost?.id,
          openHostIds: {for (final s in session.sessions) s.host.id},
          readyHostIds: {
            for (final s in session.sessions)
              if (s.isReady) s.host.id,
          },
          embedded: widget.embedded,
          onAdd: _openAddMenu,
          onSettings: _openSettings,
          onExportQr: _exportQr,
          onOpen: _openHost,
          onEdit: (host) => _openForm(host: host),
          onDelete: _deleteHost,
          onDisconnect: _disconnect,
          onExportKey: _exportKey,
          onExportPublicKey: _exportPublicKey,
        );
      },
    );
  }
}

