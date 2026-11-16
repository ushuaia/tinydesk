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
    this.latency,
  });

  final ConnectionPhase phase;
  final String? message;
  final Duration? latency;

  ConnectionSnapshot copyWith({
    ConnectionPhase? phase,
    String? message,
    Duration? latency,
  }) {
    return ConnectionSnapshot(
      phase: phase ?? this.phase,
      message: message ?? this.message,
      latency: latency ?? this.latency,
    );
  }
}
