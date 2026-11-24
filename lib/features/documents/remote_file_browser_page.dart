import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../platform/web_data.dart';

import 'package:flutter/services.dart';

import '../../data/explorer_state_store.dart';
import '../../session/session_scope.dart';
import '../../data/favorite_store.dart';
import '../../data/favorite_sync.dart';
import '../../data/remote_file.dart';
import '../../platform/file_saver.dart';
import '../../platform/rail_input_blocker.dart';
import '../../opencode/opencode_client.dart';
import '../../ssh/tunnel_session.dart';
import 'document_handle.dart';
import 'document_paths.dart';
import 'document_sync.dart';
import 'file_browser_widgets.dart';
import 'document_handles.dart';
import 'explorer_tree.dart';
import '../workspace/floating_window_header.dart';

/// The single files page: file content on the right, a collapsible
/// mini-rail on the left that expands into the directory tree ("peek"
/// pattern, like VS Code's collapsed panels).
///
/// Every reader (markdown, pdf, office, image) and the code editor are
/// embedded here instead of opening separate routes.
/// True when [documentPath] is [deletedPath] itself or lives inside it.
bool documentLivesUnder(String documentPath, String deletedPath) {
  if (documentPath == deletedPath) return true;
  final prefix = deletedPath.endsWith('/') ? deletedPath : '$deletedPath/';
  return documentPath.startsWith(prefix);
}

typedef DocumentHandleFactory = DocumentHandle? Function({
  required TunnelSession session,
  required RemoteFile file,
  required String hostId,
  required String projectRoot,
  required String userScope,
});

class RemoteFileBrowserPage extends StatefulWidget {
  /// Height of the actions row under the shared floating window header.
  static const _floatingToolbarHeight = 44.0;

  const RemoteFileBrowserPage({
    super.key,
    required this.session,
    this.initialPath = '',
    this.projectRoot = '',
    this.userScope = '',
    this.hostName = '',
    required this.hostId,
    this.initialFile,
    this.initialRequestId = 0,
    this.onPendingConsumed,
    this.documentHandleFactory = createDocumentHandle,
    this.floating = false,
    this.active = true,
  });

  final TunnelSession session;
  final String initialPath;
  final String projectRoot;
  final String userScope;

  /// Shown in the floating window header as `<hostName> · 文件`.
  final String hostName;
  final String hostId;

  /// Opened inline right after the page appears (recent documents, direct
  /// document links).
  final RemoteFile? initialFile;

  /// Distinguishes two requests for the same [RemoteFile] instance.
  final int initialRequestId;

  /// Called once a pending request has been handled, so the host can clear it.
  final VoidCallback? onPendingConsumed;

  /// Builds the content handle for a file; overridable for tests.
  final DocumentHandleFactory documentHandleFactory;

  /// Floating mode: the back affordance minimizes instead of navigating and
  /// closing asks the host to hide the window.
  final bool floating;

  /// False while this page is kept alive but another host is displayed; it
  /// must not drive the process-wide macOS input blocker.
  final bool active;

  @override
  State<RemoteFileBrowserPage> createState() => _RemoteFileBrowserPageState();
}

class _RemoteFileBrowserPageState extends State<RemoteFileBrowserPage> {
  late String _path;
  final FavoriteIndex _favorites = FavoriteIndex();
  late final ExplorerStateStore _explorerStore;
  List<String> _expanded = const [];
  double _treeWidth = 260;
  int _treeRefreshToken = 0;
  bool _railOpen = false;
  bool _blockerRegistered = false;
  bool _blockerEngaged = false;
  Timer? _docSyncTimer;
  final DocSyncPolicy _syncPolicy = DocSyncPolicy();
  DocumentHandle? _doc;
  List<RemoteFile> _roots = const [];
  RemoteFile? _currentFile;
  Set<String> _favoritePaths = {};
  bool _isFavorite = false;

  void _onDocChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadFavoritePaths() async {
    final items = await _favorites.load();
    if (!mounted) return;
    setState(() {
      _favoritePaths = {for (final item in items) item.path};
    });
  }

  /// Longest known project root containing [path], so `.tinydesk` metadata
  /// lands in the project rather than in an arbitrary parent directory.
  String _projectRootFor(String path) =>
      projectRootFor(path, roots: _roots, fallback: widget.projectRoot);

  /// Best effort: upload this project's favorites after a local change.
  Future<void> _pushFavorites(String projectRoot) async {
    if (projectRoot.isEmpty || projectRoot == '/') return;
    try {
      if (!mounted) return;
      final manager = SessionScope.of(context);
      await FavoriteSync(manager: manager).syncProject(
        session: widget.session,
        hostId: widget.hostId,
        projectRoot: projectRoot,
        userScope: widget.userScope,
      );
    } catch (_) {}
  }

  Future<void> _toggleFavorite(RemoteFile file) async {
    final isFavorite = _favoritePaths.contains(file.path);
    if (isFavorite) {
      await _favorites.remove(hostId: widget.hostId, path: file.path);
    } else {
      await _favorites.add(
        FavoriteDocument(
          path: file.path,
          name: file.name,
          kind: documentKind(file),
          addedAt: DateTime.now(),
          hostId: widget.hostId,
          projectRoot: _projectRootFor(file.path),
        ),
      );
    }
    unawaited(_pushFavorites(_projectRootFor(file.path)));
    await _loadFavoritePaths();
    if (!mounted) return;
    if (_currentFile?.path == file.path) {
      setState(() => _isFavorite = !isFavorite);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isFavorite ? AppL10n.t.unfavorited : AppL10n.t.favorited)),
    );
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFile;
    _path = initial == null ? widget.initialPath : parentPath(initial.path);
    // Seed a synchronous root so the tree's first mount can restore the
    // persisted expansion state before the async project list arrives.
    final seedRoot = widget.projectRoot.isEmpty ? '/' : widget.projectRoot;
    _roots = [
      RemoteFile(
        name: baseName(seedRoot),
        path: seedRoot,
        isDirectory: true,
      ),
    ];
    _explorerStore = ExplorerStateStore();
    unawaited(_loadExplorerState(initial));
    if (widget.initialPath.isEmpty && initial == null) {
      unawaited(_bootstrapHome());
    } else {
      unawaited(_loadRoots());
    }
    unawaited(_loadFavoritePaths());
    _docSyncTimer?.cancel();
    _docSyncTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_syncDocTick()),
    );
    if (initial != null) {
      _openPending(initial);
    }
  }

  void _openPending(RemoteFile file) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _openFile(file);
      if (mounted) widget.onPendingConsumed?.call();
    });
  }

  @override
  void didUpdateWidget(covariant RemoteFileBrowserPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pending = widget.initialFile;
    if (pending != null && widget.initialRequestId != oldWidget.initialRequestId) {
      _openPending(pending);
    }
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _blockerRegistered = true;
        RailInputBlocker.register(_onBlockerIntercepted);
      }
      _syncRailInputBlocker();
    }
  }

  /// Floating mode can be created without a path: ask the host for $HOME and
  /// seed the tree before loading the project roots.
  Future<void> _bootstrapHome() async {
    final home = await widget.session.homeDirectory();
    if (!mounted) return;
    setState(() {
      _path = home;
      _roots = [
        RemoteFile(name: baseName(home), path: home, isDirectory: true),
      ];
    });
    await _loadRoots();
  }

  Future<void> _loadExplorerState(RemoteFile? initial) async {
    final state = await _explorerStore.load(widget.hostId);
    if (!mounted) return;
    setState(() {
      _expanded = state.expandedPaths;
      _treeWidth = state.treeWidth.clamp(220.0, 340.0);
      // Entering the files page always shows the tree; opening a file later
      // collapses it to focus the content.
      _railOpen = true;
    });
  }

  void _setRail(bool open) {
    if (!mounted) return;
    setState(() => _railOpen = open);
    unawaited(_explorerStore.saveMiniRail(widget.hostId, open));
    _syncRailInputBlocker();
  }

  /// macOS: let the native layer swallow clicks/scroll over the content
  /// while the tree panel covers it (Flutter overlays cannot receive those
  /// events above the WKWebView platform view).
  void _onBlockerIntercepted() {
    if (mounted) _setRail(false);
  }

  void _syncRailInputBlocker() {
    if (!widget.active) {
      if (_blockerEngaged) {
        _blockerEngaged = false;
        unawaited(RailInputBlocker.setBlocking(blocking: false));
      }
      return;
    }
    if (!_blockerRegistered) {
      _blockerRegistered = true;
      RailInputBlocker.register(_onBlockerIntercepted);
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final size = MediaQuery.of(context).size;
    final narrow = size.width < 700;
    final paneWidth = narrow
        ? (size.width * 0.82).clamp(220.0, 340.0)
        : _treeWidth;
    final top = widget.floating
        ? FloatingWindowHeader.height + RemoteFileBrowserPage._floatingToolbarHeight
        : MediaQuery.of(context).padding.top + kToolbarHeight;
    _blockerEngaged = _railOpen;
    unawaited(
      RailInputBlocker.setBlocking(
        blocking: _railOpen,
        left: _railOpen ? paneWidth : 0,
        top: top,
      ),
    );
  }

  Future<bool> _confirmCloseDoc() async {
    final doc = _doc;
    if (doc == null) return true;
    final ok = await doc.confirmClose(context);
    if (!ok) return false;
    doc.removeListener(_onDocChanged);
    await doc.close();
    doc.dispose();
    if (mounted) {
      setState(() {
        _doc = null;
        _currentFile = null;
        _isFavorite = false;
      });
    }
    return true;
  }

  Future<void> _closeDoc() async {
    await _confirmCloseDoc();
  }

  Future<void> _openFile(RemoteFile file) async {
    if (!await _confirmCloseDoc()) return;
    final handle = widget.documentHandleFactory(
      session: widget.session,
      file: file,
      hostId: widget.hostId,
      projectRoot: widget.projectRoot,
      userScope: widget.userScope,
    );
    if (handle == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.unsupportedFile(file.extension))),
      );
      return;
    }
    handle.addListener(_onDocChanged);
    setState(() {
      _doc = handle;
      _railOpen = false;
      _currentFile = file;
      _isFavorite = _favoritePaths.contains(file.path);
    });
    unawaited(_explorerStore.saveMiniRail(widget.hostId, false));
  }

  void _selectDirectory(String path) {
    // Clicking a directory only moves the tree cursor; the panel stays open
    // so browsing continues. The content area keeps the current file.
    if (_path == path) return;
    setState(() => _path = path);
  }

  Future<void> _handleBack() async {
    // Tiered: first reveal the tree, then confirm leaving the page.
    if (!_railOpen) {
      _setRail(true);
      return;
    }
    final doc = _doc;
    // Save/discard prompt first (if dirty), but keep the file open until the
    // user confirms leaving the page.
    if (doc != null && !await doc.confirmClose(context)) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppL10n.t.closeFilePageTitle),
        content: Text(AppL10n.t.closeFilePageBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL10n.t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppL10n.t.close),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (doc != null) {
      doc.removeListener(_onDocChanged);
      await doc.close();
      doc.dispose();
      if (mounted) setState(() => _doc = null);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Widget _tree() {
    return ExplorerTree(
      session: widget.session,
      roots: _roots,
      currentPath: _path,
      expandedPaths: _expanded,
      refreshToken: _treeRefreshToken,
      autoSync: widget.active,
      onDirectorySelected: _selectDirectory,
      onFileSelected: (file) => unawaited(_openFile(file)),
      onExpandedChanged: (paths) {
        setState(() => _expanded = paths);
        unawaited(_explorerStore.saveExpanded(widget.hostId, paths));
      },
      onDownload: (file) => unawaited(_download(file)),
      onDelete: (file) => unawaited(_deleteFile(file)),
      favoritePaths: _favoritePaths,
      onToggleFavorite: (file) => unawaited(_toggleFavorite(file)),
      onCopyPath: (file) async {
        await Clipboard.setData(ClipboardData(text: file.path));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.t.pathCopied)),
        );
      },
    );
  }

  /// True when [path] lies inside [parent] (parent is a strict ancestor).
  void _addRoot(String path) {
    if (path.isEmpty || path == '/' || baseName(path).isEmpty) return;
    final hasIt = _roots.any((root) => root.path == path);
    if (hasIt) return;
    setState(() {
      _roots = [
        ..._roots,
        RemoteFile(name: baseName(path), path: path, isDirectory: true),
      ];
    });
  }

  /// Collects the host's project directories (opencode history) plus the
  /// initial root, shown as multiple roots in the tree.
  Future<void> _loadRoots() async {
    final paths = <String>{
      if (widget.projectRoot.isNotEmpty) widget.projectRoot,
      if (_path != '/' && _path.isNotEmpty) _path,
    };
    try {
      final manager = SessionScope.of(context);
      final active = manager.activeSession;
      final snapshot = active?.connection.state;
      if (snapshot != null) {
        final origin = 'http://127.0.0.1:${active!.host.localPort}';
        final cookie = await const WebData().sessionCookie(active.host.localPort);
        final projects = await OpencodeClient().listProjects(
          origin,
          cookieName: cookie?.key,
          cookieValue: cookie?.value,
        );
        for (final project in projects) {
          if (project.directory.isNotEmpty && project.directory != '/') {
            paths.add(project.directory);
          }
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _roots = [
        for (final path in paths)
          RemoteFile(
            name: baseName(path),
            path: path,
            isDirectory: true,
          ),
      ];
    });
  }

  /// Path levels for the breadcrumb bar: `/`, `/home`, `/home/user`, …
  List<({String label, String path})> get _crumbs {
    final crumbs = <({String label, String path})>[
      (label: '/', path: '/'),
    ];
    if (_path != '/') {
      var accumulated = '';
      for (final part in _path.split('/').where((p) => p.isNotEmpty)) {
        accumulated = '$accumulated/$part';
        crumbs.add((label: part, path: accumulated));
      }
    }
    return crumbs;
  }

  Widget _breadcrumbs(BuildContext context) =>
      BreadcrumbsBar(labels: [for (final crumb in _crumbs) crumb.label]);

  Future<void> _download(RemoteFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp('tinydesk_download_');
      final temp = File('${tempDir.path}/${file.name}');
      await widget.session.downloadFile(file.path, temp);
      final bytes = await temp.readAsBytes();
      final saver = const FileSaver();
      final saved = await saver.save(
        name: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(saved == null ? AppL10n.t.downloadCancelled : AppL10n.t.savedTo(saved)),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(AppL10n.t.downloadFailed(error.toString()))),
      );
    } finally {
      if (tempDir != null) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<void> _deleteFile(RemoteFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppL10n.t.deleteFileTitle(file.name)),
        content: Text(
          file.isDirectory
              ? AppL10n.t.folderDeleteWarning
              : AppL10n.t.deleteIrreversible,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL10n.t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppL10n.t.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.session.delete(file.path);
      if (!mounted) return;
      final current = _currentFile;
      if (current != null && documentLivesUnder(current.path, file.path)) {
        final doc = _doc;
        if (doc != null) {
          doc.removeListener(_onDocChanged);
          await doc.close();
          doc.dispose();
        }
        setState(() {
          _doc = null;
          _currentFile = null;
          _isFavorite = false;
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.fileDeleted(file.name))),
      );
      setState(() => _treeRefreshToken++);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.deleteFailed(error.toString()))),
      );
    }
  }

  Future<void> _createFile() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppL10n.t.newFile),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: AppL10n.t.fileName,
            hintText: AppL10n.t.fileNameHint,
          ),
          onSubmitted: (value) =>
              Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppL10n.t.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(AppL10n.t.create),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    if (name.contains('/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.fileNameNoSlash)),
      );
      return;
    }
    final base = _path.endsWith('/') ? _path : '$_path/';
    final target = '$base$name';
    try {
      final files = await widget.session.listDirectory(_path);
      final exists = files.any((file) => file.name == name);
      if (exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.t.fileExists)),
        );
        return;
      }
      await widget.session.writeText(target, '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.fileCreated(name))),
      );
      setState(() => _treeRefreshToken++);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.createFailed(error.toString()))),
      );
    }
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppL10n.t.newFolder),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: AppL10n.t.folderName),
          onSubmitted: (value) =>
              Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppL10n.t.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(AppL10n.t.create),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    if (name.contains('/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.nameNoSlash)),
      );
      return;
    }
    final base = _path.endsWith('/') ? _path : '$_path/';
    try {
      await widget.session.createDirectory('$base$name');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.folderCreated(name))),
      );
      setState(() => _treeRefreshToken++);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.createFailed(error.toString()))),
      );
    }
  }

  Future<void> _promptPath() async {
    final controller = TextEditingController(text: _path);
    final path = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppL10n.t.jumpToPathTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '/home/user/project',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppL10n.t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(AppL10n.t.jump),
          ),
        ],
      ),
    );
    if (path != null && path.isNotEmpty) {
      _selectDirectory(path);
      _addRoot(path);
    }
  }

  @override
  void dispose() {
    _docSyncTimer?.cancel();
    if (_blockerEngaged) {
      unawaited(RailInputBlocker.setBlocking(blocking: false));
    }
    if (_blockerRegistered) RailInputBlocker.unregisterIf(_onBlockerIntercepted);
    final doc = _doc;
    if (doc != null) {
      doc.removeListener(_onDocChanged);
      unawaited(doc.close());
      doc.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final wide = MediaQuery.of(context).size.width >= 700;
    if (doc != null) doc.navigatorContext = context;
    _syncRailInputBlocker();

    if (widget.floating) {
      return Material(
        child: Column(
          children: [
            FloatingWindowHeader(
              leadingIcon: Icons.folder_open,
              title: widget.hostName.isEmpty
                  ? AppL10n.t.filesTitle
                  : AppL10n.t.filesTitleW(widget.hostName),
            ),
            Container(
              height: RemoteFileBrowserPage._floatingToolbarHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(children: _windowActions(context, doc, wide)),
            ),
            Expanded(child: _bodyWithMobileGestures(context)),
          ],
        ),
      );
    }

    final scaffold = Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: AppL10n.t.back,
            onPressed: () => unawaited(_handleBack()),
          ),
          title: doc == null
              ? _breadcrumbs(context)
              : _docTitle(context, doc),
          actions: [
            ..._windowActions(context, doc, wide, includeCloseFile: true),
            const SizedBox(width: 4),
          ],
        ),
        body: _bodyWithMobileGestures(context),
    );
    if (widget.floating) return scaffold;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: scaffold,
    );
  }

  /// Window chrome shared by the floating window and the full-screen page:
  /// document-level actions first, then the page-level ones.
  List<Widget> _windowActions(
    BuildContext context,
    DocumentHandle? doc,
    bool wide, {
    bool includeCloseFile = false,
  }) {
    return [
      if (doc != null) ...[
        IconButton(
          onPressed: _currentFile == null
              ? null
              : () => unawaited(_toggleFavorite(_currentFile!)),
          icon: Icon(
            _isFavorite ? Icons.star : Icons.star_border,
            color: _isFavorite ? Theme.of(context).colorScheme.primary : null,
          ),
          iconSize: 20,
          tooltip: _isFavorite ? AppL10n.t.unfavorite : AppL10n.t.favorite,
        ),
        ...doc.buildActions(context),
        if (includeCloseFile)
          IconButton(
            onPressed: () => unawaited(_closeDoc()),
            icon: const Icon(Icons.close),
            iconSize: 18,
            tooltip: AppL10n.t.closeFile,
          ),
        if (wide) const ActionDivider(),
      ],
      if (wide || doc == null) ...[
        IconButton(
          onPressed: () => _setRail(!_railOpen),
          icon: const Icon(Icons.account_tree_outlined),
          iconSize: 20,
          tooltip: _railOpen ? AppL10n.t.collapseTree : AppL10n.t.expandTree,
        ),
        if (wide) const ActionDivider(),
        IconButton(
          onPressed: _createFile,
          icon: const Icon(Icons.note_add_outlined),
          iconSize: 20,
          tooltip: AppL10n.t.newFile,
        ),
        IconButton(
          onPressed: _createFolder,
          icon: const Icon(Icons.create_new_folder_outlined),
          iconSize: 20,
          tooltip: AppL10n.t.newFolder,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          tooltip: AppL10n.t.more,
          onSelected: (value) {
            if (value == 'refresh') unawaited(_refresh());
            if (value == 'jump') unawaited(_promptPath());
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'refresh', child: Text(AppL10n.t.refresh)),
            PopupMenuItem(value: 'jump', child: Text(AppL10n.t.jumpToPath)),
          ],
        ),
      ],
    ];
  }

  /// Auto-sync tick: detect server-side changes to the open document.
  /// Clean documents reload automatically; documents with unsaved edits
  /// never get overwritten — a snackbar notes the conflict instead.
  Future<void> _syncDocTick() async {
    if (!mounted || !widget.active) return;
    final doc = _doc;
    if (doc == null) return;
    try {
      final changed = await doc.checkExternalUpdate();
      final action = _syncPolicy.decide(
        changed: changed,
        dirty: doc.dirty,
        now: DateTime.now(),
      );
      switch (action) {
        case DocSyncAction.none:
          return;
        case DocSyncAction.conflict:
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppL10n.t.docConflict(doc.title))),
          );
        case DocSyncAction.reload:
          await doc.reloadExternalChanges();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppL10n.t.docReloaded(doc.title))),
          );
      }
    } catch (_) {}
  }

  void _refreshTree() {
    setState(() => _treeRefreshToken++);
  }

  /// Refresh re-reads the open document too: edits made outside the app were
  /// invisible because only the tree used to be rebuilt.
  Future<void> _refresh() async {
    _refreshTree();
    final file = _currentFile;
    if (file == null) return;
    await _openFile(file);
  }

  bool _isNarrow(BuildContext context) =>
      MediaQuery.of(context).size.width < 700;

  Widget _bodyWithMobileGestures(BuildContext context) {
    final narrow = _isNarrow(context);
    final paneWidth = narrow
        ? (MediaQuery.of(context).size.width * 0.82).clamp(220.0, 340.0)
        : _treeWidth;
    // Overlay drawer: the content keeps its full size and is simply covered
    // (clipped) by the tree panel while open.
    return Stack(
      children: [
        Positioned.fill(child: _content(context)),
        if (_railOpen) ...[
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: paneWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                // Swiping left on the panel itself closes it.
                if ((details.primaryVelocity ?? 0) < -200) {
                  _setRail(false);
                }
              },
              child: Material(
                elevation: 12,
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                child: _treePanel(context),
              ),
            ),
          ),
          Positioned(
            left: paneWidth,
            top: 0,
            bottom: 0,
            width: 6,
            child: narrow
                ? const SizedBox.shrink()
                : TreeDragBar(
                    onDragEnd: () => unawaited(
                      _explorerStore.saveWidth(widget.hostId, _treeWidth),
                    ),
                    onDrag: (delta) {
                      setState(() {
                        _treeWidth =
                            (_treeWidth + delta).clamp(220.0, 340.0);
                      });
                    },
                  ),
          ),
          // While the tree is open, interacting with the content area closes
          // it first (classic drawer behaviour), on every platform.
          Positioned(
            left: paneWidth,
            top: 0,
            right: 0,
            bottom: 0,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _setRail(false),
              onPointerSignal: (_) => _setRail(false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setRail(false),
                onHorizontalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) < -200) {
                    _setRail(false);
                  }
                },
                child: Container(
                  color: narrow
                      ? const Color(0x0D000000)
                      : const Color(0x00000000),
                ),
              ),
            ),
          ),
        ] else
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: narrow
                ? SizedBox(
                    width: 16,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _setRail(true),
                      onHorizontalDragEnd: (details) {
                        if ((details.primaryVelocity ?? 0) > 200) {
                          _setRail(true);
                        }
                      },
                    ),
                  )
                : _miniRail(context),
          ),
      ],
    );
  }

  Widget _treePanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      child: Column(
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.only(left: 14, right: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: scheme.outlineVariant),
                right: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Text(
                  AppL10n.t.directoryTree,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _setRail(false),
                  icon: const Icon(Icons.keyboard_double_arrow_left),
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  tooltip: AppL10n.t.collapseTree,
                ),
              ],
            ),
          ),
          Expanded(child: _tree()),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final doc = _doc;
    if (doc == null) return _emptyContent(context);
    return doc.buildBody(context);
  }

  /// Window-side title row for an open document (app bar level).
  Widget _docTitle(BuildContext context, DocumentHandle doc) =>
      DocumentTitleBar(doc: doc, icon: iconForFileTitle(doc.title));


  Widget _miniRail(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: AppL10n.t.expandTree,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setRail(true),
        child: Container(
          width: 10,
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            Icons.chevron_right,
            size: 14,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _emptyContent(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.account_tree_outlined,
              size: 40,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppL10n.t.selectFromTree,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              _path,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            onPressed: () => _setRail(true),
            icon: const Icon(Icons.account_tree_outlined, size: 18),
            label: Text(AppL10n.t.openTree),
          ),
        ],
      ),
    );
  }
}
