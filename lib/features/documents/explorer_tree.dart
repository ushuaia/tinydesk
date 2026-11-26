import 'dart:async';
import '../../core/app_language.dart';

import 'dart:io';

import 'package:flutter/material.dart';



import '../../data/remote_file.dart';
import '../../ssh/tunnel_session.dart';
import 'anchored_menu.dart';

/// Lazily-loaded directory tree used by the file explorer.
///
/// Children are fetched only when a directory is expanded (SFTP friendly).
/// The tree is purely navigational: tapping a directory asks the host page to
/// switch the right pane, tapping a file opens it in the reader/editor.
class ExplorerTree extends StatefulWidget {
  const ExplorerTree({
    super.key,
    required this.session,
    required this.roots,
    required this.currentPath,
    required this.expandedPaths,
    required this.onDirectorySelected,
    required this.onFileSelected,
    required this.onExpandedChanged,
    this.showHidden = true,
    this.initialSelectedRoot,
    this.onSelectedRootChanged,
    this.onDownload,
    this.onCopyPath,
    this.onDelete,
    this.favoritePaths = const {},
    this.onToggleFavorite,
    this.refreshToken = 0,
    this.autoSync = false,
  });

  final TunnelSession session;
  final List<RemoteFile> roots;

  /// Whether dotfiles and dot directories are listed.
  final bool showHidden;

  /// Root the tree should show first (restored from the last visit).
  final String? initialSelectedRoot;

  /// Fires when the user picks a root, so the page can persist it.
  final ValueChanged<String>? onSelectedRootChanged;
  final String currentPath;
  final List<String> expandedPaths;
  final ValueChanged<String> onDirectorySelected;
  final ValueChanged<RemoteFile> onFileSelected;
  final ValueChanged<List<String>> onExpandedChanged;
  final ValueChanged<RemoteFile>? onDownload;
  final ValueChanged<RemoteFile>? onCopyPath;
  final ValueChanged<RemoteFile>? onDelete;
  final Set<String> favoritePaths;
  final ValueChanged<RemoteFile>? onToggleFavorite;

  /// Bump to invalidate cached listings (after create/refresh).
  final int refreshToken;

  /// When true, polls the mtimes of expanded directories every few seconds
  /// so external changes show up without a manual refresh.
  final bool autoSync;

  @override
  State<ExplorerTree> createState() => _ExplorerTreeState();
}

class _ExplorerTreeState extends State<ExplorerTree> {
  final Map<String, List<RemoteFile>> _children = {};
  /// Readable message per directory that failed to list.
  final Map<String, String> _errors = {};
  /// Last known mtime per listed directory, for the auto-sync poller.
  final Map<String, DateTime?> _dirMtimes = {};
  Timer? _autoSyncTimer;
  final Set<String> _loading = {};
  // Expansion of plain directories, keyed by path.
  final Set<String> _expanded = {};
  // Expansion of root rows, keyed independently so a root and a folder
  // with the same path remain separate instances.
  final Set<String> _rootExpanded = {};
  late List<RemoteFile> _roots = [...widget.roots];
  /// Root shown in the tree; the other project roots live in the dropdown.
  String? _selectedRoot;
  bool _userPickedRoot = false;
  final GlobalKey _rootButtonKey = GlobalKey();
  OverlayEntry? _rootMenuEntry;
  bool _rootMenuOpen = false;

  @override
  void initState() {
    super.initState();
    // Only persist-provided expansions apply; project roots stay collapsed
    // and are lazily loaded when expanded.
    _restoreExpansions(widget.expandedPaths);
    if (widget.autoSync) {
      _startAutoSync();
    }
    // Restored expanded nodes have no cached children yet: kick off their
    // lazy loads so the tree actually shows the contents.
    for (final path in _expanded) {
      unawaited(_loadDirectory(path));
    }
    for (final key in _rootExpanded) {
      unawaited(_loadDirectory(key.substring(5)));
    }
    unawaited(_expandAncestors(widget.currentPath));
    _selectedRoot = widget.initialSelectedRoot ?? _rootFor(widget.currentPath);
    final selected = _selectedRoot;
    if (selected != null && !_children.containsKey(selected)) {
      unawaited(_loadDirectory(selected));
    }
  }

  /// Deepest root that contains [path] (or null when none does).
  String? _rootFor(String path) {
    String? best;
    for (final root in _roots) {
      if (root.path.isEmpty) continue;
      final inside = path == root.path || path.startsWith('${root.path}/');
      if (inside && (best == null || root.path.length > best.length)) {
        best = root.path;
      }
    }
    return best;
  }

  /// Selected root, falling back to the current path's root and then to the
  /// first root when the previous selection disappeared.
  String? get _effectiveRoot {
    final selected = _selectedRoot;
    if (selected != null && _roots.any((root) => root.path == selected)) {
      return selected;
    }
    final fallback = _rootFor(widget.currentPath) ??
        (_roots.isEmpty ? null : _roots.first.path);
    _selectedRoot = fallback;
    return fallback;
  }

  void _selectRoot(String path) {
    if (_selectedRoot == path) return;
    _userPickedRoot = true;
    setState(() => _selectedRoot = path);
    widget.onSelectedRootChanged?.call(path);
    if (!_children.containsKey(path)) {
      unawaited(_loadDirectory(path));
    }
  }

  void _restoreExpansions(Iterable<String> paths) {
    for (final entry in paths) {
      if (entry.startsWith('root:')) {
        final path = entry.substring(5);
        if (_roots.any((root) => root.path == path)) {
          _rootExpanded.add(entry);
        }
      } else if (_roots.any((root) => entry.startsWith(root.path))) {
        _expanded.add(entry);
      }
    }
  }

  /// Persisted expansion state: child folders plus root namespace keys.
  List<String> _expansionPayload() => [..._expanded, ..._rootExpanded];

  @override
  void didUpdateWidget(ExplorerTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      unawaited(_refreshExpanded());
    }
    if (widget.autoSync != oldWidget.autoSync) {
      if (widget.autoSync) {
        _startAutoSync();
      } else {
        _autoSyncTimer?.cancel();
        _autoSyncTimer = null;
      }
    }
    if (oldWidget.currentPath != widget.currentPath) {
      final isRoot = widget.roots.any((root) => root.path == widget.currentPath);
      if (!isRoot) {
        unawaited(_expandAncestors(widget.currentPath));
      }
      final target = _rootFor(widget.currentPath);
      if (target != null && target != _selectedRoot) {
        setState(() => _selectedRoot = target);
        if (!_children.containsKey(target)) {
          unawaited(_loadDirectory(target));
        }
      }
    }
    if (widget.initialSelectedRoot != null &&
        widget.initialSelectedRoot != oldWidget.initialSelectedRoot &&
        !_userPickedRoot) {
      final restored = widget.initialSelectedRoot!;
      if (_selectedRoot != restored) {
        // didUpdateWidget is followed by a build; calling setState here can
        // mark the page dirty mid-build.
        _selectedRoot = restored;
        if (!_children.containsKey(restored)) {
          unawaited(_loadDirectory(restored));
        }
      }
    }
    final oldRoots = oldWidget.roots.map((r) => r.path).toSet();
    final newRoots = widget.roots.where((r) => !oldRoots.contains(r.path)).toList();
    if (newRoots.isNotEmpty) {
      _roots = [...widget.roots];
      _restoreExpansions(widget.expandedPaths);
      for (final path in _expanded) {
        if (!_children.containsKey(path)) {
          unawaited(_loadDirectory(path));
        }
      }
      for (final key in _rootExpanded) {
        final path = key.substring(5);
        if (!_children.containsKey(path)) {
          unawaited(_loadDirectory(path));
        }
      }
      final selected = _effectiveRoot;
      if (selected != null && !_children.containsKey(selected)) {
        unawaited(_loadDirectory(selected));
      }
    }
  }

  @override
  void dispose() {
    _rootMenuEntry?.remove();
    _rootMenuEntry = null;
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshExpanded() async {
    final paths = _children.keys.toList();
    _children.clear();
    _errors.clear();
    setState(() {});
    for (final path in paths) {
      await _loadDirectory(path);
    }
  }

  Future<void> _expandAncestors(String path) async {
    final ancestors = <String>[];
    var current = path;
    while (current != '/' && current.length > 1) {
      final slash = current.lastIndexOf('/');
      if (slash <= 0) break;
      current = current.substring(0, slash);
      if (_roots.any((root) => current.startsWith(root.path))) {
        ancestors.add(current);
      }
    }
    var changed = false;
    for (final ancestor in ancestors.reversed) {
      if (_expanded.add(ancestor)) changed = true;
      if (!_children.containsKey(ancestor)) {
        await _loadDirectory(ancestor);
      }
    }
    if (changed && mounted) {
      widget.onExpandedChanged(_expansionPayload());
    }
  }

  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_refreshExpandedIfChanged());
    });
  }

  /// Stats each expanded directory and re-lists the ones whose mtime moved.
  Future<void> _refreshExpandedIfChanged() async {
    if (!widget.autoSync || !mounted) return;
    for (final path in _children.keys.toList()) {
      if (_loading.contains(path)) continue;
      final modified = await widget.session.statModified(path);
      if (modified == null) continue;
      final previous = _dirMtimes[path];
      if (previous != null && !modified.isAfter(previous)) continue;
      if (!mounted) return;
      // Keep the cached listing on screen until the new one arrives; clearing
      // it first made the folder blink empty every time it changed.
      await _loadDirectory(path);
    }
  }

  Future<void> _loadDirectory(String path) async {
    if (_loading.contains(path)) return;
    _loading.add(path);
    try {
      // Copy before sorting: a session may hand back a fixed-length list.
      final files = [...await widget.session.listDirectory(path)];
      final mtime = await widget.session.statModified(path);
      files.sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      if (!mounted) return;
      setState(() {
        _children[path] = files;
        _dirMtimes[path] = mtime;
        _errors.remove(path);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _children[path] = const [];
        _errors[path] = _describeDirectoryError(error);
      });
    } finally {
      _loading.remove(path);
    }
  }

  void _toggle(RemoteFile directory) {
    final rootKey = 'root:${directory.path}';
    final isRoot = _roots.any((root) => root.path == directory.path);
    if (isRoot) {
      setState(() {
        if (_rootExpanded.contains(rootKey)) {
          _rootExpanded.remove(rootKey);
        } else {
          // 工程根互斥：同一时刻只展开一个工程。
          _rootExpanded.clear();
          _rootExpanded.add(rootKey);
          if (!_children.containsKey(directory.path)) {
            unawaited(_loadDirectory(directory.path));
          }
        }
      });
    } else if (_expanded.contains(directory.path)) {
      setState(() => _expanded.remove(directory.path));
    } else {
      setState(() => _expanded.add(directory.path));
      if (!_children.containsKey(directory.path)) {
        unawaited(_loadDirectory(directory.path));
      }
    }
    widget.onExpandedChanged(_expansionPayload());
    widget.onDirectorySelected(directory.path);
  }

  String _basename(String path) {
    if (path == '/' || path.isEmpty) return '/';
    final trimmed =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final slash = trimmed.lastIndexOf('/');
    return slash < 0 ? trimmed : trimmed.substring(slash + 1);
  }

  @override
  Widget build(BuildContext context) {
    final root = _effectiveRoot;
    final rows = <Widget>[];
    if (root != null) {
      _appendChildren(rows, root, 0);
    }
    return Column(
      children: [
        if (_roots.isNotEmpty) _rootSelector(context, root),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 4),
            children: rows,
          ),
        ),
      ],
    );
  }

  /// Header dropdown: one project root at a time, instead of stacking every
  /// project directory in the tree.
  Widget _rootSelector(BuildContext context, String? selected) {
    final scheme = Theme.of(context).colorScheme;
    final current = _roots.firstWhere(
      (root) => root.path == selected,
      orElse: () => _roots.first,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: GestureDetector(
        key: const ValueKey('root-button'),
        onTap: () => _toggleRootMenu(context),
        child: Container(
          key: _rootButtonKey,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_open,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  current.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: _rootMenuOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 120),
                child: Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Anchors the menu panel directly under the button.
  Future<void> _toggleRootMenu(BuildContext context) async {
    if (_rootMenuOpen) return;
    final overlayRender = Overlay.of(context).context.findRenderObject();
    if (overlayRender is! RenderBox || !overlayRender.hasSize) return;
    final buttonBox = _rootButtonKey.currentContext?.findRenderObject();
    if (buttonBox is! RenderBox || !buttonBox.hasSize) return;
    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayRender,
    );
    final anchor = Rect.fromLTWH(
      buttonTopLeft.dx,
      buttonTopLeft.dy,
      buttonBox.size.width,
      buttonBox.size.height,
    );
    final currentPath = _effectiveRoot ?? '';
    setState(() => _rootMenuOpen = true);
    final selected = await AnchoredMenu.show(
      context: context,
      anchor: anchor,
      width: 280,
      selectedValue: currentPath,
      items: [
        for (final root in _roots)
          AnchoredMenuItem(
            label: root.name,
            subtitle: root.path,
            value: root.path,
            leading: Icon(
              root.path == currentPath ? Icons.check : Icons.folder_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
    if (mounted) setState(() => _rootMenuOpen = false);
    if (selected is String) _selectRoot(selected);
  }


  void _appendRows(
    List<Widget> rows,
    String path,
    int depth, {
    bool isRoot = false,
    String? rootLabel,
  }) {
    final expanded = isRoot
        ? _rootExpanded.contains('root:$path')
        : _expanded.contains(path);
    rows.add(
      _TreeRow(
        label: rootLabel ?? _basename(path),
        depth: depth,
        isDirectory: true,
        expanded: expanded,
        loading: _loading.contains(path),
        highlighted: path == widget.currentPath,
        onTap: () => _toggle(RemoteFile(
          name: _basename(path),
          path: path,
          isDirectory: true,
        )),
      ),
    );
    if (!expanded) return;
    _appendChildren(rows, path, depth + 1);
  }

  void _appendChildren(List<Widget> rows, String path, int depth) {
    final loading = _loading.contains(path);
    final children = _children[path];
    if (children == null) {
      if (loading) {
        rows.add(_LoadingRow(depth: depth));
      }
      return;
    }
    final error = _errors[path];
    if (error != null) {
      rows.add(
        _ErrorRow(
          depth: depth,
          message: error,
          onRetry: () {
            _errors.remove(path);
            _children.remove(path);
            unawaited(_loadDirectory(path));
          },
        ),
      );
    }
    for (final file in children) {
      // Dotfiles stay in the cache; visibility is a render-time switch.
      if (!widget.showHidden && file.name.startsWith('.')) continue;
      if (file.isDirectory) {
        _appendRows(rows, file.path, depth);
      } else {
        rows.add(
          _TreeRow(
            label: file.name,
            depth: depth,
            isDirectory: false,
            expanded: false,
            loading: false,
            highlighted: file.path == widget.currentPath,
            icon: _icon(file),
            onTap: () => widget.onFileSelected(file),
            file: file,
            onDownload: widget.onDownload,
            onCopyPath: widget.onCopyPath,
            onDelete: widget.onDelete,
            favorite: widget.favoritePaths.contains(file.path),
            onToggleFavorite: widget.onToggleFavorite,
          ),
        );
      }
    }
  }

  IconData _icon(RemoteFile file) {
    if (file.isMarkdown) return Icons.description_outlined;
    if (file.isPdf) return Icons.picture_as_pdf_outlined;
    if (file.isImage) return Icons.image_outlined;
    if (file.isText) return Icons.code;
    return Icons.insert_drive_file_outlined;
  }
}
class _TreeRow extends StatefulWidget {
  const _TreeRow({
    required this.label,
    required this.depth,
    required this.isDirectory,
    required this.expanded,
    required this.loading,
    required this.highlighted,
    required this.onTap,
    this.icon,
    this.file,
    this.onDownload,
    this.onCopyPath,
    this.onDelete,
    this.favorite = false,
    this.onToggleFavorite,
  });

  final String label;
  final int depth;
  final bool isDirectory;
  final bool expanded;
  final bool loading;
  final bool highlighted;
  final VoidCallback onTap;
  final IconData? icon;
  final RemoteFile? file;
  final ValueChanged<RemoteFile>? onDownload;
  final ValueChanged<RemoteFile>? onCopyPath;
  final ValueChanged<RemoteFile>? onDelete;
  final bool favorite;
  final ValueChanged<RemoteFile>? onToggleFavorite;

  @override
  State<_TreeRow> createState() => _TreeRowState();
}

class _TreeRowState extends State<_TreeRow> {
  bool _hovered = false;

  /// Anchored popup: opens below the row, clamped inside the overlay.
  Future<void> _showMenu(BuildContext context) async {
    final file = widget.file;
    if (file == null) return;
    final overlayRender = Overlay.of(context).context.findRenderObject();
    if (overlayRender is! RenderBox || !overlayRender.hasSize) return;
    final rowBox = context.findRenderObject();
    if (rowBox is! RenderBox || !rowBox.hasSize) return;
    final rowTopLeft = rowBox.localToGlobal(
      Offset.zero,
      ancestor: overlayRender,
    );
    const menuWidth = 200.0;
    final left = (rowTopLeft.dx + rowBox.size.width - menuWidth)
        .clamp(0.0, overlayRender.size.width - menuWidth)
        .toDouble();
    final value = await AnchoredMenu.show(
      context: context,
      anchor: Rect.fromLTWH(
        left,
        rowTopLeft.dy,
        menuWidth,
        rowBox.size.height,
      ),
      width: menuWidth,
      items: [
        AnchoredMenuItem(label: AppL10n.t.open, value: 'open'),
        if (widget.onToggleFavorite != null)
          AnchoredMenuItem(
            label: widget.favorite
                ? AppL10n.t.unfavorite
                : AppL10n.t.favorite,
            value: 'favorite',
          ),
        AnchoredMenuItem(label: AppL10n.t.download, value: 'download'),
        AnchoredMenuItem(label: AppL10n.t.copyPath, value: 'copy'),
        if (widget.onDelete != null)
          AnchoredMenuItem(label: AppL10n.t.delete, value: 'delete'),
      ],
    );
    if (!context.mounted) return;
    if (value == 'open') widget.onTap();
    if (value == 'favorite') widget.onToggleFavorite?.call(file);
    if (value == 'download') widget.onDownload?.call(file);
    if (value == 'copy') widget.onCopyPath?.call(file);
    if (value == 'delete') widget.onDelete?.call(file);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // VSCode-style selection: a quiet accent wash, the label keeps its colour.
    final background = widget.highlighted
        ? scheme.primary.withValues(alpha: 0.10)
        : _hovered
            ? scheme.onSurface.withValues(alpha: 0.05)
            : null;
    final iconColor =
        widget.highlighted ? scheme.primary : scheme.onSurfaceVariant;
    final file = widget.file;
    final hasMenu = file != null &&
        (widget.onDownload != null ||
            widget.onCopyPath != null ||
            widget.onToggleFavorite != null);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: const EdgeInsets.only(left: 8, right: 2),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              SizedBox(
                width: widget.depth * 14,
                child: CustomPaint(
                  size: Size(widget.depth * 14, 28),
                  painter: _GuidePainter(
                    depth: widget.depth,
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
              ),
              SizedBox(
                width: 16,
                child: widget.isDirectory
                    ? (widget.loading
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child:
                                CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : AnimatedRotation(
                            turns: widget.expanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 120),
                            child: Icon(
                              Icons.chevron_right,
                              size: 15,
                              color: iconColor,
                            ),
                          ))
                    : const SizedBox.shrink(),
              ),
              Icon(
                widget.isDirectory
                    ? (widget.expanded ? Icons.folder_open : Icons.folder)
                    : (widget.icon ?? Icons.insert_drive_file_outlined),
                size: 15,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurface,
                    fontWeight: widget.isDirectory
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (hasMenu)
                Tooltip(
                  message: AppL10n.t.actions,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => unawaited(_showMenu(context)),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Icon(
                        Icons.more_horiz,
                        size: 15,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.depth});

  final int depth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20.0 + depth * 14,
        top: 4,
        bottom: 4,
      ),
      child: Text(
        AppL10n.t.loading,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

/// Turns a directory listing failure into something the user can act on.
String _describeDirectoryError(Object error) {
  if (error is FileSystemException) {
    final code = error.osError?.errorCode;
    if (code == 1 || code == 13) {
      return AppL10n.t.permissionDenied;
    }
    if (error.message.isNotEmpty) return error.message;
  }
  return AppL10n.t.cannotReadDirectory;
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({
    required this.depth,
    required this.message,
    required this.onRetry,
  });

  final int depth;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20.0 + depth * 14,
        right: 8,
        top: 2,
        bottom: 2,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: scheme.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.error),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(AppL10n.t.retry, style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}


/// Faint vertical lines under each ancestor level, like VSCode's guides.
class _GuidePainter extends CustomPainter {
  const _GuidePainter({required this.depth, required this.color});

  final int depth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var i = 0; i < depth; i++) {
      final x = i * 14.0 + 7;
      canvas.drawLine(Offset(x, 4), Offset(x, size.height - 4), paint);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter oldDelegate) =>
      oldDelegate.depth != depth || oldDelegate.color != color;
}
