import 'dart:async';
import '../../core/app_language.dart';
import '../../core/ball_snap.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../session/app_session_manager.dart';
import '../../session/host_session.dart';
import '../../ssh/tunnel_session.dart';
import '../../session/file_browser_controller.dart';
import 'floating_file_browser_shell.dart';
import 'remote_file_browser_page.dart';

const _ballSize = 56.0;
const _edge = 12.0;
const _ballXKey = 'filebrowser.ball.x';
const _ballYKey = 'filebrowser.ball.y';

/// Root-level host for the floating file browser.
///
/// Every session that has been opened at least once keeps a live
/// [RemoteFileBrowserPage] inside an [IndexedStack], so minimizing and
/// switching hosts never destroys the browsing state.
class FloatingFileBrowserHost extends StatefulWidget {
  const FloatingFileBrowserHost({super.key, required this.manager});

  final AppSessionManager manager;

  @override
  State<FloatingFileBrowserHost> createState() =>
      _FloatingFileBrowserHostState();
}

class _FloatingFileBrowserHostState extends State<FloatingFileBrowserHost>
    with WidgetsBindingObserver {
  Offset? _ballOffset;
  final Map<String, GlobalKey> _pageKeys = {};
  // Keep the last live tunnel per host so a blip does not unmount the page
  // (which would silently drop unsaved edits).
  final Map<String, TunnelSession> _lastTunnels = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadBallOffset());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    final controller = widget.manager.fileBrowser;
    if (controller == null || !controller.expanded) return false;
    controller.minimize();
    return true;
  }

  Future<void> _loadBallOffset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final x = prefs.getDouble(_ballXKey);
      final y = prefs.getDouble(_ballYKey);
      if (x != null && y != null) {
        setState(() => _ballOffset = Offset(x, y));
      }
    } catch (_) {}
  }

  void _snapAndSaveBall(Size screen, EdgeInsets safe) {
    final current = _ballOffset ?? _defaultOffset(screen, safe);
    setState(() {
      _ballOffset = snapBallToEdge(current, screen, safe, _ballSize);
    });
    unawaited(_saveBallOffset());
  }

  Future<void> _saveBallOffset() async {
    final offset = _ballOffset;
    if (offset == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_ballXKey, offset.dx);
      await prefs.setDouble(_ballYKey, offset.dy);
    } catch (_) {}
  }

  Offset _defaultOffset(Size screen, EdgeInsets safe) {
    return Offset(
      screen.width - _ballSize - _edge,
      (screen.height - safe.bottom) * 0.42,
    );
  }

  void _dragBall(Offset delta, Size screen, EdgeInsets safe) {
    final current = _ballOffset ?? _defaultOffset(screen, safe);
    final next = current + delta;
    final minY = safe.top + _edge;
    final maxY = math.max(
      minY,
      screen.height - safe.bottom - _ballSize - _edge,
    );
    setState(() {
      _ballOffset = Offset(
        next.dx
            .clamp(_edge, math.max(_edge, screen.width - _ballSize - _edge))
            .toDouble(),
        next.dy.clamp(minY, maxY).toDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.manager,
      builder: (context, _) {
        final media = MediaQuery.of(context);
        final opened = [
          for (final session in widget.manager.sessions)
            if (session.fileBrowser.visible) session,
        ];
        final controller = widget.manager.fileBrowser;
        if (controller == null || !controller.visible) {
          return const SizedBox.shrink();
        }
        return FloatingFileBrowserShell(
          visible: true,
          expanded: controller.expanded,
          ballOffset:
              _ballOffset ?? _defaultOffset(media.size, media.padding),
          onBallTap: widget.manager.showFileBrowser,
          onBallDragUpdate: (delta) =>
              _dragBall(delta, media.size, media.padding),
          onBallDragEnd: () => _snapAndSaveBall(media.size, media.padding),
          child: _buildWindows(opened),
        );
      },
    );
  }

  Widget _buildWindows(List<HostSession> opened) {
    if (opened.isEmpty) return const SizedBox.shrink();
    final current = activeWindowIndex(
      [for (final session in opened) session.host.id],
      widget.manager.activeSession?.host.id,
    );
    return IndexedStack(
      index: current,
      children: [
        for (var i = 0; i < opened.length; i++)
          _buildWindow(opened[i], active: i == current),
      ],
    );
  }

  Widget _buildWindow(HostSession session, {required bool active}) {
    final key = _pageKeys.putIfAbsent(session.host.id, GlobalKey.new);
    final controller = session.fileBrowser;
    final live = session.connection.session;
    if (live != null) _lastTunnels[session.host.id] = live;
    final tunnel = live ?? _lastTunnels[session.host.id];
    if (tunnel == null) {
      return _NotReadyWindow(controller: controller);
    }
    return RemoteFileBrowserPage(
      key: key,
      session: tunnel,
      hostId: session.host.id,
      userScope: session.host.username,
      floating: true,
      active: active,
      projectRoot: controller.pendingProjectRoot,
      initialFile: controller.pendingFile,
      initialRequestId: controller.pendingRequestId,
      onPendingConsumed: controller.consumePendingFile,
      controller: controller,
    );
  }
}

/// Shown when a host never connected (or its tunnel is gone before the first
/// page mount). Keeps a way out: minimize or close.
class _NotReadyWindow extends StatelessWidget {
  const _NotReadyWindow({required this.controller});

  final FileBrowserController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          tooltip: AppL10n.t.minimize,
          onPressed: controller.minimize,
        ),
        title: Text(AppL10n.t.connectionNotReady),
        actions: [
          IconButton(
            onPressed: controller.close,
            icon: const Icon(Icons.close),
            iconSize: 18,
            tooltip: AppL10n.t.closeWindow,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(child: Text(AppL10n.t.connectionNotReady)),
    );
  }
}

/// Index of the window to display inside the [IndexedStack].
@visibleForTesting
int activeWindowIndex(List<String> hostIds, String? activeHostId) {
  if (hostIds.isEmpty) return 0;
  final index = hostIds.indexOf(activeHostId ?? '');
  return index < 0 ? 0 : index;
}
