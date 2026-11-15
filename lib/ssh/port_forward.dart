import 'dart:io';

import '../core/app_language.dart';

import 'package:dartssh2/dartssh2.dart';

import 'ssh_errors.dart';

class LocalForward {
  LocalForward(this._server, this._channels, this.localPort);

  final ServerSocket _server;
  final Set<SSHSocket> _channels;
  final int localPort;

  Future<void> close() async {
    await _server.close();
    for (final channel in _channels.toList()) {
      channel.destroy();
    }
    _channels.clear();
  }
}

class PortForwarder {
  Future<void> ensurePortAvailable(int port) async {
    try {
      final socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await socket.close();
    } on SocketException catch (error) {
      throw TunnelFailed(AppL10n.t.localPortBusy(port.toString()), cause: error);
    }
  }

  /// 模拟 `ssh -L localPort:127.0.0.1:remotePort`。
  ///
  /// dartssh2 4.x 的 [SSHClient.forwardLocal] 只打开一条到远端的通道，
  /// 不再本地监听，因此这里自己 bind 本地端口并为每条连接建通道。
  Future<LocalForward> start(
    SSHClient client, {
    required int localPort,
    required int remotePort,
  }) async {
    await ensurePortAvailable(localPort);
    try {
      final channels = <SSHSocket>{};
      final server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        localPort,
      );

      server.listen((socket) async {
        try {
          final channel = await client.forwardLocal('127.0.0.1', remotePort);
          channels.add(channel);

          socket.listen(
            channel.sink.add,
            onDone: () {
              channel.close();
              channels.remove(channel);
            },
            onError: (_) => socket.destroy(),
          );

          channel.stream.listen(
            socket.add,
            onDone: () {
              socket.destroy();
              channels.remove(channel);
            },
            onError: (_) => socket.destroy(),
          );
        } catch (_) {
          socket.destroy();
        }
      });

      return LocalForward(server, channels, localPort);
    } on SshError {
      rethrow;
    } catch (error) {
      throw TunnelFailed(AppL10n.t.tunnelFailed(error.toString()), cause: error);
    }
  }
}
