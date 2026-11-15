import 'package:flutter/material.dart';

import '../../core/app_language.dart';


import '../../core/connection_state.dart';

class ConnectView extends StatelessWidget {
  const ConnectView({super.key, required this.snapshot, this.onCancel});

  final ConnectionSnapshot snapshot;
  final VoidCallback? onCancel;

  static final _labels = {
    ConnectionPhase.idle: AppL10n.t.preparing,
    ConnectionPhase.sshConnecting: AppL10n.t.sshConnecting,
    ConnectionPhase.authenticating: AppL10n.t.verifyingKey,
    ConnectionPhase.tunneling: AppL10n.t.establishingTunnel,
    ConnectionPhase.probing: AppL10n.t.detectingOpencode,
    ConnectionPhase.startingServer: AppL10n.t.startingOpencodeService,
    ConnectionPhase.pairing: AppL10n.t.pairing,
    ConnectionPhase.ready: AppL10n.t.connected,
    ConnectionPhase.reconnecting: AppL10n.t.reconnecting,
    ConnectionPhase.failed: AppL10n.t.connectionFailedTitle,
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (snapshot.phase == ConnectionPhase.failed)
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              )
            else
              const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _labels[snapshot.phase] ?? '',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (snapshot.message != null) ...[
              const SizedBox(height: 8),
              Text(
                snapshot.message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (snapshot.phase == ConnectionPhase.failed && onCancel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onCancel, child: Text(AppL10n.t.back)),
            ],
          ],
        ),
      ),
    );
  }
}
