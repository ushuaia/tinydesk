sealed class OpencodeError implements Exception {
  const OpencodeError(this.userMessage, {this.cause});

  final String userMessage;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $userMessage';
}

class OpencodeNotInstalled extends OpencodeError {
  const OpencodeNotInstalled(super.userMessage, {super.cause});
}

class ServerUnreachable extends OpencodeError {
  const ServerUnreachable(super.userMessage, {super.cause});
}

class PairingFailed extends OpencodeError {
  const PairingFailed(super.userMessage, {super.cause});
}

class ServiceStartFailed extends OpencodeError {
  const ServiceStartFailed(super.userMessage, {super.cause});
}
