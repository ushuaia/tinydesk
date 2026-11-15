import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A file the user starred, available across sessions and hosts.
class FavoriteDocument {
  const FavoriteDocument({
    required this.path,
    required this.name,
    required this.kind,
    required this.addedAt,
    this.updatedAt,
    this.deleted = false,
    this.hostId,
    this.projectRoot,
  });

  final String path;
  final String name;

  /// markdown / pdf / office / image / text … (free-form tag).
  final String kind;
  final DateTime addedAt;

  /// Last local change (add, remove). Falls back to [addedAt] for entries
  /// written before cross-device sync existed.
  final DateTime? updatedAt;

  /// Tombstone: the entry stays in the store so deletions can travel between
  /// devices, but the UI hides it.
  final bool deleted;

  final String? hostId;
  final String? projectRoot;

  DateTime get changedAt => updatedAt ?? addedAt;

  FavoriteDocument copyWith({
    String? name,
    String? kind,
    DateTime? addedAt,
    DateTime? updatedAt,
    bool? deleted,
    String? hostId,
    String? projectRoot,
  }) {
    return FavoriteDocument(
      path: path,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      hostId: hostId ?? this.hostId,
      projectRoot: projectRoot ?? this.projectRoot,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'kind': kind,
        'addedAt': addedAt.toIso8601String(),
        'updatedAt': (updatedAt ?? addedAt).toIso8601String(),
        'deleted': deleted,
        'hostId': hostId,
        'projectRoot': projectRoot,
      };

  factory FavoriteDocument.fromJson(Map<String, dynamic> json) {
    final addedAt = json['addedAt'] == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.parse(json['addedAt'] as String);
    final updatedAt = json['updatedAt'] == null
        ? null
        : DateTime.tryParse(json['updatedAt'] as String);
    return FavoriteDocument(
      path: json['path'] as String,
      name: json['name'] as String,
      kind: json['kind'] as String? ?? 'file',
      addedAt: addedAt,
      updatedAt: updatedAt ?? addedAt,
      deleted: json['deleted'] as bool? ?? false,
      hostId: json['hostId'] as String?,
      projectRoot: json['projectRoot'] as String?,
    );
  }
}

/// Merges local and remote entries by path, keeping the most recent change.
///
/// Remote entries live inside a project's `.tinydesk/favorites.json` and carry
/// no host binding; they are attached to the local host here.
List<FavoriteDocument> mergeFavorites(
  List<FavoriteDocument> local,
  List<FavoriteDocument> remote, {
  String? hostId,
  String? projectRoot,
}) {
  final byPath = <String, FavoriteDocument>{
    for (final item in local) item.path: item,
  };
  for (final item in remote) {
    final bound = item.copyWith(hostId: hostId, projectRoot: projectRoot);
    final existing = byPath[item.path];
    if (existing == null || bound.changedAt.isAfter(existing.changedAt)) {
      byPath[item.path] = bound;
    }
  }
  return byPath.values.toList();
}

/// Project-side file format: `{"version":1,"favorites":{path: {...}}}`.
Map<String, dynamic> serializeRemoteFavorites(List<FavoriteDocument> docs) {
  return {
    'version': 1,
    'favorites': {
      for (final doc in docs)
        doc.path: {
          'name': doc.name,
          'kind': doc.kind,
          'addedAt': doc.addedAt.toIso8601String(),
          'updatedAt': doc.changedAt.toIso8601String(),
          'deleted': doc.deleted,
        },
    },
  };
}

List<FavoriteDocument> parseRemoteFavorites(
  Object? json, {
  required String hostId,
  required String projectRoot,
}) {
  if (json is! Map) return const [];
  final favorites = json['favorites'];
  if (favorites is! Map) return const [];
  final result = <FavoriteDocument>[];
  for (final entry in favorites.entries) {
    final path = entry.key;
    final value = entry.value;
    if (path is! String || value is! Map) continue;
    final addedAt = value['addedAt'] is String
        ? DateTime.tryParse(value['addedAt'] as String)
        : null;
    if (addedAt == null) continue;
    result.add(
      FavoriteDocument(
        path: path,
        name: value['name'] as String? ?? path.split('/').last,
        kind: value['kind'] as String? ?? 'file',
        addedAt: addedAt,
        updatedAt: value['updatedAt'] is String
            ? DateTime.tryParse(value['updatedAt'] as String)
            : addedAt,
        deleted: value['deleted'] as bool? ?? false,
        hostId: hostId,
        projectRoot: projectRoot,
      ),
    );
  }
  return result;
}

/// Global favorites list (grouped by host in the UI).
class FavoriteIndex {
  static const _key = 'favorites.v1';

  /// Visible favorites (tombstones removed), newest first.
  Future<List<FavoriteDocument>> load() async {
    final all = await loadAll();
    final visible = all.where((item) => !item.deleted).toList();
    visible.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return visible;
  }

  /// All entries including tombstones; used by the sync layer.
  Future<List<FavoriteDocument>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return <FavoriteDocument>[];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => FavoriteDocument.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <FavoriteDocument>[];
    }
  }

  Future<void> _saveAll(List<FavoriteDocument> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(favorites.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> add(FavoriteDocument doc) async {
    try {
      final all = await loadAll();
      final now = DateTime.now();
      all.removeWhere(
        (item) => item.hostId == doc.hostId && item.path == doc.path,
      );
      all.insert(
        0,
        doc.copyWith(updatedAt: now, deleted: false, addedAt: doc.addedAt),
      );
      await _saveAll(all);
    } catch (_) {}
  }

  /// Marks an entry as deleted so the deletion can reach other devices.
  Future<void> remove({required String hostId, required String path}) async {
    try {
      final all = await loadAll();
      final now = DateTime.now();
      var changed = false;
      for (var i = 0; i < all.length; i++) {
        final item = all[i];
        if (item.hostId == hostId && item.path == path) {
          all[i] = item.copyWith(updatedAt: now, deleted: true);
          changed = true;
        }
      }
      if (changed) await _saveAll(all);
    } catch (_) {}
  }

  Future<void> removeForHost(String hostId) async {
    try {
      final all = await loadAll();
      all.removeWhere((item) => item.hostId == hostId);
      await _saveAll(all);
    } catch (_) {}
  }

  /// Replaces the entries belonging to one project with the merged result.
  Future<void> replaceProject(
    String hostId,
    String projectRoot,
    List<FavoriteDocument> entries,
  ) async {
    final all = await loadAll();
    all.removeWhere(
      (item) =>
          item.hostId == hostId &&
          (item.projectRoot ?? '') == (projectRoot),
    );
    all.addAll(entries);
    await _saveAll(all);
  }

  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  Future<bool> contains(String hostId, String path) async {
    final favorites = await load();
    return favorites
        .any((item) => item.hostId == hostId && item.path == path);
  }
}
