import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted explorer state per host: expanded tree nodes and tree width.
class ExplorerState {
  const ExplorerState({
    this.expandedPaths = const [],
    this.treeWidth = 280,
    this.miniRailOpen = false,
    this.showHidden = true,
    this.selectedRoot = '',
    this.openDocPaths = const [],
    this.activeDocPath = '',
  });

  final List<String> expandedPaths;
  final double treeWidth;
  final bool miniRailOpen;
  final bool showHidden;
  final String selectedRoot;

  /// Files left open when the browser was last used; restored on the next
  /// visit so the same project and pages come back.
  final List<String> openDocPaths;
  final String activeDocPath;
}

class ExplorerStateStore {
  static const _expandedPrefix = 'explorer.expanded.v1.';
  static const _widthPrefix = 'explorer.width.v1.';
  static const _railPrefix = 'explorer.miniRail.v1.';
  static const _hiddenPrefix = 'explorer.showHidden.v1.';
  static const _rootPrefix = 'explorer.selectedRoot.v1.';
  static const _docsPrefix = 'explorer.openDocs.v1.';

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
      final hidden = prefs.getBool('$_hiddenPrefix$hostId') ?? true;
      final root = prefs.getString('$_rootPrefix$hostId') ?? '';
      final docsRaw = prefs.getString('$_docsPrefix$hostId');
      final docs = docsRaw == null
          ? const <String>[]
          : (jsonDecode(docsRaw) as List<dynamic>)
              .map((item) => item as String)
              .toList();
      return ExplorerState(
        expandedPaths: expanded,
        treeWidth: width,
        miniRailOpen: rail,
        showHidden: hidden,
        selectedRoot: root,
        openDocPaths: docs,
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

  Future<void> saveSelectedRoot(String hostId, String root) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_rootPrefix$hostId', root);
    } catch (_) {}
  }

  Future<void> saveOpenDocs(
    String hostId,
    List<String> paths,
    String activePath,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_docsPrefix$hostId', jsonEncode(paths));
      await prefs.setString('$_rootPrefix$hostId', activePath);
    } catch (_) {}
  }

  Future<void> saveShowHidden(String hostId, bool show) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_hiddenPrefix$hostId', show);
    } catch (_) {}
  }

  Future<void> saveMiniRail(String hostId, bool open) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_railPrefix$hostId', open);
    } catch (_) {}
  }
}
