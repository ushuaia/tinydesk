import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted explorer state per host: expanded tree nodes and tree width.
class ExplorerState {
  const ExplorerState({
    this.expandedPaths = const [],
    this.treeWidth = 280,
    this.miniRailOpen = false,
  });

  final List<String> expandedPaths;
  final double treeWidth;
  final bool miniRailOpen;
}

class ExplorerStateStore {
  static const _expandedPrefix = 'explorer.expanded.v1.';
  static const _widthPrefix = 'explorer.width.v1.';
  static const _railPrefix = 'explorer.miniRail.v1.';

  Future<ExplorerState> load(String hostId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_expandedPrefix$hostId');
      final expanded = raw == null
          ? const <String>[]
          : (jsonDecode(raw) as List<dynamic>)
              .map((item) => item as String)
              .toList();
      final width = prefs.getDouble('$_widthPrefix$hostId') ?? 280;
      final rail = prefs.getBool('$_railPrefix$hostId') ?? true;
      return ExplorerState(
        expandedPaths: expanded,
        treeWidth: width,
        miniRailOpen: rail,
      );
    } catch (_) {
      return const ExplorerState();
    }
  }

  Future<void> saveExpanded(String hostId, List<String> paths) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_expandedPrefix$hostId', jsonEncode(paths));
    } catch (_) {}
  }

  Future<void> saveWidth(String hostId, double width) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('$_widthPrefix$hostId', width);
    } catch (_) {}
  }

  Future<void> saveMiniRail(String hostId, bool open) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_railPrefix$hostId', open);
    } catch (_) {}
  }
}
