class Host {
  const Host({
    required this.id,
    required this.name,
    this.type = 'ssh',
    required this.host,
    required this.port,
    required this.username,
    required this.remotePort,
    required this.localPort,
    required this.autoStartServer,
    this.privateKeyRef,
    this.hasPassphrase = false,
    this.knownHostFingerprint,
    this.lastConnectedAt,
  });

  final String id;
  final String name;

  /// `'ssh'` for a remote host reached over SSH, `'local'` for the machine
  /// the app is running on (no SSH involved).
  final String type;

  final String host;
  final int port;
  final String username;
  final String? privateKeyRef;
  final bool hasPassphrase;
  final int remotePort;
  final int localPort;
  final bool autoStartServer;
  final String? knownHostFingerprint;
  final DateTime? lastConnectedAt;

  bool get isLocal => type == 'local';
  bool get isSsh => type == 'ssh';

  Host copyWith({
    String? name,
    String? type,
    String? host,
    int? port,
    String? username,
    String? privateKeyRef,
    bool? hasPassphrase,
    int? remotePort,
    int? localPort,
    bool? autoStartServer,
    String? knownHostFingerprint,
    DateTime? lastConnectedAt,
  }) {
    return Host(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      privateKeyRef: privateKeyRef ?? this.privateKeyRef,
      hasPassphrase: hasPassphrase ?? this.hasPassphrase,
      remotePort: remotePort ?? this.remotePort,
      localPort: localPort ?? this.localPort,
      autoStartServer: autoStartServer ?? this.autoStartServer,
      knownHostFingerprint: knownHostFingerprint ?? this.knownHostFingerprint,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'host': host,
        'port': port,
        'username': username,
        'privateKeyRef': privateKeyRef,
        'hasPassphrase': hasPassphrase,
        'remotePort': remotePort,
        'localPort': localPort,
        'autoStartServer': autoStartServer,
        'knownHostFingerprint': knownHostFingerprint,
        'lastConnectedAt': lastConnectedAt?.toIso8601String(),
      };

  factory Host.fromJson(Map<String, dynamic> json) => Host(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String? ?? 'ssh',
        host: json['host'] as String,
        port: json['port'] as int,
        username: json['username'] as String,
        privateKeyRef: json['privateKeyRef'] as String?,
        hasPassphrase: json['hasPassphrase'] as bool? ?? false,
        remotePort: json['remotePort'] as int? ?? 49374,
        localPort: json['localPort'] as int? ?? 49375,
        autoStartServer: json['autoStartServer'] as bool? ?? true,
        knownHostFingerprint: json['knownHostFingerprint'] as String?,
        lastConnectedAt: json['lastConnectedAt'] == null
            ? null
            : DateTime.parse(json['lastConnectedAt'] as String),
      );
}
