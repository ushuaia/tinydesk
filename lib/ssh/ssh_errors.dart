import '../core/app_language.dart';

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
    return NetworkUnreachable(AppL10n.t.cannotReachHost(host, port.toString()), cause: error);
  }
  if (text.contains('auth') || text.contains('permission denied')) {
    return SshAuthFailed(AppL10n.t.keyRejected, cause: error);
  }
  if (text.contains('host key') || text.contains('fingerprint')) {
    return HostKeyMismatch(AppL10n.t.hostKeyVerificationFailed, cause: error);
  }
  return UnknownSshError(AppL10n.t.sshConnectFailed(error.toString()), cause: error);
}
