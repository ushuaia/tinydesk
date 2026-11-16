enum ConnectionPhase {
  idle,
  sshConnecting,
  authenticating,
  tunneling,
  probing,
  startingServer,
  ready,
  reconnecting,
  failed,
}

class ConnectionSnapshot {
  const ConnectionSnapshot({
    required this.phase,
    this.message,
    this.pairUrl,
    this.cookieName,
    this.cookieValue,
    this.latency,
  });

  final ConnectionPhase phase;
  final String? message;
  final String? pairUrl;
  final String? cookieName;
  final String? cookieValue;
  final Duration? latency;

  ConnectionSnapshot copyWith({
    ConnectionPhase? phase,
    String? message,
    String? pairUrl,
    String? cookieName,
    String? cookieValue,
    Duration? latency,
  }) {
    return ConnectionSnapshot(
      phase: phase ?? this.phase,
      message: message ?? this.message,
      pairUrl: pairUrl ?? this.pairUrl,
      cookieName: cookieName ?? this.cookieName,
      cookieValue: cookieValue ?? this.cookieValue,
      latency: latency ?? this.latency,
    );
  }
}
