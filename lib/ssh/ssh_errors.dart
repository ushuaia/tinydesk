sealed class SshError implements Exception {
  const SshError(this.userMessage, {this.cause});

  final String userMessage;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $userMessage';
}

class NetworkUnreachable extends SshError {
  const NetworkUnreachable(super.userMessage, {super.cause});
}

class SshAuthFailed extends SshError {
  const SshAuthFailed(super.userMessage, {super.cause});
}

class HostKeyMismatch extends SshError {
  const HostKeyMismatch(super.userMessage, {super.cause});
}

class TunnelFailed extends SshError {
  const TunnelFailed(super.userMessage, {super.cause});
}

class UnknownSshError extends SshError {
  const UnknownSshError(super.userMessage, {super.cause});
}

SshError mapSshException(
  Object error, {
  required String host,
  required int port,
}) {
  final text = error.toString().toLowerCase();
  if (text.contains('socket') ||
      text.contains('connection refused') ||
      text.contains('timed out') ||
      text.contains('network is unreachable') ||
      text.contains('no route to host')) {
    return NetworkUnreachable('无法连接主机 $host:$port，请检查网络', cause: error);
  }
  if (text.contains('auth') || text.contains('permission denied')) {
    return SshAuthFailed('密钥被拒绝，请检查公钥是否已加入主机', cause: error);
  }
  if (text.contains('host key') || text.contains('fingerprint')) {
    return HostKeyMismatch('主机指纹校验失败', cause: error);
  }
  return UnknownSshError('SSH 连接失败：$error', cause: error);
}
