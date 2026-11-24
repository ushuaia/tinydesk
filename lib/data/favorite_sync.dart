import '../session/app_session_manager.dart';
import '../core/connection_state.dart';
import '../session/host_session.dart';
import '../opencode/opencode_client.dart';
import '../ssh/tunnel_session.dart';
import 'favorite_store.dart';
import 'project_metadata_store.dart';
import '../platform/web_data.dart';

/// Keeps favorites in sync with each project's `.tinydesk/favorites.json`.
///
/// Local SharedPreferences stays the source for offline display; the remote
/// file is merged by path, newest change wins, and tombstones propagate
/// deletions between devices.
class FavoriteSync {
  FavoriteSync({
    required this.manager,
    FavoriteIndex? index,
    OpencodeClient? client,
  })  : index = index ?? FavoriteIndex(),
        _client = client ?? OpencodeClient();

  static const remoteFile = 'favorites.json';

  final AppSessionManager manager;
  final FavoriteIndex index;
  final OpencodeClient _client;

  /// Merges every reachable project; safe to call repeatedly.
  Future<void> syncAll() async {
    final localByHost = <String, Set<String>>{};
    for (final item in await index.loadAll()) {
      final hostId = item.hostId;
      final root = item.projectRoot;
      if (hostId == null || root == null || root.isEmpty) continue;
      localByHost.putIfAbsent(hostId, () => <String>{}).add(root);
    }

    for (final session in manager.sessions) {
      if (session.connection.state.phase != ConnectionPhase.ready) continue;
      final tunnel = session.connection.session;
      if (tunnel == null) continue;
      final roots = <String>{
        ...?localByHost[session.host.id],
        ...await _projectRoots(session),
      };
      for (final root in roots) {
        if (root.isEmpty || root == '/') continue;
        await syncProject(
          session: tunnel,
          hostId: session.host.id,
          projectRoot: root,
          userScope: session.host.username,
        );
      }
    }
  }

  Future<List<String>> _projectRoots(HostSession session) async {
    final state = session.connection.state;
    if (state.phase != ConnectionPhase.ready) return const [];
    try {
      final cookie = await const WebData().sessionCookie(session.host.localPort);
      final projects = await _client
          .listProjects(
            'http://127.0.0.1:${session.host.localPort}',
            cookieName: cookie?.key,
            cookieValue: cookie?.value,
          )
          .timeout(const Duration(seconds: 4));
      return [
        for (final project in projects)
          if (project.directory.isNotEmpty && project.directory != '/')
            project.directory,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Merges one project's favorites and writes the result back to the host.
  Future<void> syncProject({
    required TunnelSession session,
    required String hostId,
    required String projectRoot,
    String userScope = '',
    bool push = true,
  }) async {
    final metadata = ProjectMetadataStore(
      session: session,
      projectRoot: projectRoot,
      userScope: userScope,
    );

    Object? remoteJson;
    try {
      remoteJson = await metadata
          .readJson(remoteFile)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // The remote state is unknown, so merging or pushing would drop
      // entries another device wrote. Retry on the next sync instead.
      return;
    }

    final all = await index.loadAll();
    final local = all
        .where(
          (item) =>
              item.hostId == hostId &&
              (item.projectRoot ?? '') == projectRoot,
        )
        .toList();
    final remote = parseRemoteFavorites(
      remoteJson,
      hostId: hostId,
      projectRoot: projectRoot,
    );
    final merged = mergeFavorites(
      local,
      remote,
      hostId: hostId,
      projectRoot: projectRoot,
    );

    await index.replaceProject(hostId, projectRoot, merged);

    if (!push) return;
    try {
      await metadata
          .writeJson(remoteFile, serializeRemoteFavorites(merged))
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}
