import 'dart:async';
import '../../core/app_language.dart';

import 'dart:io';

import 'package:flutter/material.dart';



import '../../data/remote_file.dart';
import '../../ssh/tunnel_session.dart';

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
    }
  }

  @override
  void dispose() {
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
      setState(() {
        _children.remove(path);
        _dirMtimes.remove(path);
      });
      await _loadDirectory(path);
    }
  }

  Future<void> _loadDirectory(String path) async {
    if (_loading.contains(path)) return;
    _loading.add(path);
    try {
      final files = await widget.session.listDirectory(path);
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
    final rows = <Widget>[];
    for (final root in _roots) {
      _appendRows(rows, root.path, 0, isRoot: true, rootLabel: root.name);
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: rows,
    );
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
    final loading = _loading.contains(path);
    final children = _children[path];
    rows.add(
      _TreeRow(
        label: rootLabel ?? _basename(path),
        depth: depth,
        isDirectory: true,
        expanded: expanded,
        loading: loading,
        highlighted: path == widget.currentPath,
        onTap: () => _toggle(RemoteFile(
          name: _basename(path),
          path: path,
          isDirectory: true,
        )),
      ),
    );
    if (!expanded) return;
    if (children == null) {
      if (loading) {
        rows.add(_LoadingRow(depth: depth + 1));
      }
      return;
    }
    final error = _errors[path];
    if (error != null) {
      rows.add(
        _ErrorRow(
          depth: depth + 1,
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
      if (file.isDirectory) {
        _appendRows(rows, file.path, depth + 1);
      } else {
        rows.add(
          _TreeRow(
            label: file.name,
            depth: depth + 1,
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
class _TreeRow extends StatelessWidget {
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

  /// Anchored popup: opens below the row, clamped inside the overlay.
  Future<void> _showMenu(BuildContext context) async {
    final file = this.file;
    if (file == null) return;
    final box = context.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final corner = box.localToGlobal(
      Offset(box.size.width, box.size.height),
      ancestor: overlay,
    );
    const menuWidth = 160.0;
    final left = (corner.dx - menuWidth)
        .clamp(0.0, overlay.size.width - menuWidth);
    final position = RelativeRect.fromLTRB(
      left,
      corner.dy,
      overlay.size.width - left - menuWidth,
      overlay.size.height - corner.dy,
    );
    final value = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(value: 'open', child: Text(AppL10n.t.open)),
        if (onToggleFavorite != null)
          PopupMenuItem(
            value: 'favorite',
            child: Text(favorite ? AppL10n.t.unfavorite : AppL10n.t.favorite),
          ),
        PopupMenuItem(value: 'download', child: Text(AppL10n.t.download)),
        PopupMenuItem(value: 'copy', child: Text(AppL10n.t.copyPath)),
        if (onDelete != null)
          PopupMenuItem(value: 'delete', child: Text(AppL10n.t.delete)),
      ],
    );
    if (!context.mounted) return;
    if (value == 'open') onTap();
    if (value == 'favorite') onToggleFavorite?.call(file);
    if (value == 'download') onDownload?.call(file);
    if (value == 'copy') onCopyPath?.call(file);
    if (value == 'delete') onDelete?.call(file);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background =
        highlighted ? scheme.primaryContainer : null;
    final foreground =
        highlighted ? scheme.onPrimaryContainer : scheme.onSurface;
    final iconColor = highlighted ? scheme.primary : scheme.onSurfaceVariant;
    final hasMenu = file != null &&
        (onDownload != null ||
            onCopyPath != null ||
            onToggleFavorite != null);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: EdgeInsets.only(
            left: 8.0 + depth * 14,
            right: 2,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                child: isDirectory
                    ? (loading
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child:
                                CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : Icon(
                            expanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_right,
                            size: 15,
                            color: iconColor,
                          ))
                    : const SizedBox.shrink(),
              ),
              Icon(
                isDirectory
                    ? (expanded ? Icons.folder_open : Icons.folder)
                    : (icon ?? Icons.insert_drive_file_outlined),
                size: 15,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: foreground,
                    fontWeight:
                        isDirectory ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              if (hasMenu)
                Tooltip(
                  message: AppL10n.t.actions,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => unawaited(_showMenu(context)),
                    child: const SizedBox(
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
