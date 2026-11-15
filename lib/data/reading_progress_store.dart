import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../ssh/tunnel_session.dart';
import 'project_metadata_store.dart';

class ReadingProgressStore {
  ReadingProgressStore({
    TunnelSession? session,
    String? projectRoot,
    String? userScope,
  }) : _metadata = (session != null &&
                projectRoot != null &&
                projectRoot.isNotEmpty)
            ? ProjectMetadataStore(
                session: session,
                projectRoot: projectRoot,
                userScope: userScope ?? '',
              )
            : null;

  static const _prefix = 'reading.progress.';
  static const _remoteFileName = 'reading_progress.json';

  final ProjectMetadataStore? _metadata;

  String _key(String hostId, String path) => '$_prefix$hostId:$path';

  String _stateKey(String hostId, String path) =>
      'reading.state.$hostId:$path';

  Future<double?> load(String hostId, String path) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_key(hostId, path));
  }

  Future<void> save(String hostId, String path, double scrollY) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key(hostId, path), scrollY);
  }

  Future<double?> loadZoom(String hostId, String path) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('reading.zoom.$hostId:$path');
  }

  Future<void> saveZoom(String hostId, String path, double zoom) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reading.zoom.$hostId:$path', zoom);
  }

  /// Loads local first, then the project's remote file. The remote entry wins
  /// when its `updatedAt` is newer.
  Future<({Map<String, dynamic> state, double fontScale})?> loadBestState(
    String hostId,
    String path,
  ) async {
    final local = await loadState(hostId, path);
    final remote = await _loadRemoteState(path);
    if (remote == null) return local;
    if (local == null) {
      await saveState(
        hostId,
        path,
        state: remote.state,
        fontScale: remote.fontScale,
      );
      return remote;
    }

    final localTime = _parseTime(local.state['updatedAt']);
    final remoteTime = _parseTime(remote.state['updatedAt']);
    final remoteWins = remoteTime != null &&
        (localTime == null || remoteTime.isAfter(localTime));
    if (!remoteWins) return local;

    await saveState(
      hostId,
      path,
      state: remote.state,
      fontScale: remote.fontScale,
    );
    return remote;
  }

  /// Reader state as a JSON map plus the font scale.
  Future<({Map<String, dynamic> state, double fontScale})?> loadState(
    String hostId,
    String path,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey(hostId, path));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final fontScale = decoded['fontScale'];
      if (fontScale is! num) return null;
      final state = <String, dynamic>{
        for (final entry in decoded.entries) entry.key: entry.value,
      };
      return (state: state, fontScale: fontScale.toDouble());
    } catch (_) {
      return null;
    }
  }

  Future<void> saveState(
    String hostId,
    String path, {
    required Map<String, dynamic> state,
    required double fontScale,
    bool syncRemote = false,
  }) async {
    final payload = <String, dynamic>{
      ...state,
      'fontScale': fontScale,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey(hostId, path), jsonEncode(payload));
    await prefs.setDouble('reading.zoom.$hostId:$path', fontScale);
    if (syncRemote) {
      await _syncRemote(path, payload);
    }
  }

  Future<({Map<String, dynamic> state, double fontScale})?> _loadRemoteState(
    String path,
  ) async {
    final metadata = _metadata;
    if (metadata == null) return null;
    try {
      final data = await metadata
          .readJson(_remoteFileName)
          .timeout(const Duration(seconds: 2));
      if (data == null) return null;
      final files = data['files'];
      if (files is! Map) return null;
      final raw = files[path];
      if (raw is! Map) return null;
      final state = Map<String, dynamic>.from(raw);
      final fontScale = state['fontScale'];
      if (fontScale is! num) return null;
      return (state: state, fontScale: fontScale.toDouble());
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncRemote(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final metadata = _metadata;
    if (metadata == null) return;
    try {
      final current = await metadata
          .readJson(_remoteFileName)
          .timeout(const Duration(seconds: 2));
      final files = current != null && current['files'] is Map
          ? Map<String, dynamic>.from(current['files'] as Map)
          : <String, dynamic>{};
      files[path] = payload;
      await metadata
          .writeJson(_remoteFileName, {
            'version': 1,
            'files': files,
          })
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  DateTime? _parseTime(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}
