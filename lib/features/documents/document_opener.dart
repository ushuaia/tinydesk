import 'package:flutter/material.dart';

import '../../core/app_language.dart';


import '../../session/app_session_manager.dart';
import '../../core/connection_state.dart';
import '../../data/favorite_store.dart';
import '../../data/host.dart';
import '../../data/host_repository.dart';
import '../../data/private_key_store.dart';
import '../../data/remote_file.dart';
import 'open_document.dart';

/// Opens a document by host + path, ensuring the host session is connected
/// first. Used by the favorites page.
class DocumentOpener {
  DocumentOpener({
    required this.repository,
    required this.keyStore,
    required this.manager,
  });

  final HostRepository repository;
  final PrivateKeyStore keyStore;
  final AppSessionManager manager;

  Future<bool> open(BuildContext context, FavoriteDocument doc) async {
    final hostId = doc.hostId;
    if (hostId == null) return false;

    final hosts = await repository.all();
    Host? target;
    for (final item in hosts) {
      if (item.id == hostId) {
        target = item;
        break;
      }
    }
    if (!context.mounted) return false;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.hostDeleted)),
      );
      await FavoriteIndex().removeForHost(hostId);
      return false;
    }
    final host = target;

    var key = '';
    String? passphrase;
    if (!host.isLocal) {
      final pair = await keyStore.read(host.id);
      if (!context.mounted) return false;
      if (pair == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.t.hostKeyMissing)),
        );
        return false;
      }
      key = pair.$1;
      passphrase = pair.$2;
    }

    final needsConnect = manager.phaseOf(host.id) != ConnectionPhase.ready ||
        !manager.hasSession(host.id);
    if (needsConnect) {
      if (!manager.hasSession(host.id)) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppL10n.t.connectAndOpenTitle),
            content: Text(AppL10n.t.connectAndOpenBody(host.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppL10n.t.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppL10n.t.continueLabel),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return false;
      }

      final navigator = Navigator.of(context);
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ConnectingDialog(),
      );
      await Future<void>.delayed(Duration.zero);
      try {
        await manager.openHost(
          host,
          key,
          passphrase: passphrase,
          connect: false,
        );
        await manager.retry(host.id);
      } finally {
        navigator.pop();
      }
    }

    if (!context.mounted) return false;
    // Focus the target host so its floating window becomes the visible one.
    manager.activate(host.id);
    final session = manager.sessionOf(host.id) ?? manager.activeSession;
    final tunnel = session?.connection.session;
    if (tunnel == null || session == null || !session.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(session?.snapshot.message ?? AppL10n.t.connectionNotReady),
        ),
      );
      return false;
    }

    final file = RemoteFile(
      name: doc.name,
      path: doc.path,
      isDirectory: false,
    );
    final controller = manager.fileBrowserOf(host.id);
    if (controller == null) return false;
    return openDocument(
      context,
      manager: manager,
      file: file,
      projectRoot: doc.projectRoot ?? '',
      controller: controller,
    );
  }
}

class _ConnectingDialog extends StatelessWidget {
  const _ConnectingDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 16),
          Text(AppL10n.t.connectingHost),
        ],
      ),
    );
  }
}
