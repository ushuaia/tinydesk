import 'package:flutter/material.dart';

import '../../core/connection_state.dart';

class ConnectView extends StatelessWidget {
  const ConnectView({super.key, required this.snapshot, this.onCancel});

  final ConnectionSnapshot snapshot;
  final VoidCallback? onCancel;

  static const _labels = {
    ConnectionPhase.idle: '准备中',
    ConnectionPhase.sshConnecting: '连接 SSH…',
    ConnectionPhase.authenticating: '验证密钥…',
    ConnectionPhase.tunneling: '建立隧道…',
    ConnectionPhase.probing: '检测 opencode…',
    ConnectionPhase.startingServer: '启动 opencode 服务…',
    ConnectionPhase.pairing: '配对中…',
    ConnectionPhase.ready: '已连接',
    ConnectionPhase.reconnecting: '正在重连…',
    ConnectionPhase.failed: '连接失败',
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
              OutlinedButton(onPressed: onCancel, child: const Text('返回')),
            ],
          ],
        ),
      ),
    );
  }
}
