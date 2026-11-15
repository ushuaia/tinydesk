import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/app_language.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_session_manager.dart';
import '../workspace/floating_window_header.dart';
import 'terminal_controller.dart';
import 'terminal_view_host.dart';

const _ballSize = 56.0;
const _edge = 12.0;
const _ballXKey = 'terminal.ball.x';
const _ballYKey = 'terminal.ball.y';

class FloatingTerminalHost extends StatefulWidget {
  const FloatingTerminalHost({super.key, required this.manager});

  final AppSessionManager manager;

  @override
  State<FloatingTerminalHost> createState() => _FloatingTerminalHostState();
}

class _FloatingTerminalHostState extends State<FloatingTerminalHost> {
  Offset? _ballOffset;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBallOffset());
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

  Future<void> _saveBallOffset() async {
    final offset = _ballOffset;
    if (offset == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_ballXKey, offset.dx);
      await prefs.setDouble(_ballYKey, offset.dy);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.manager,
      builder: (context, _) {
        // Show the active host's terminal. Other sessions keep their own
        // terminals running in the background — switching never closes them.
        final terminal = widget.manager.terminal;
        if (!terminal.visible) return const SizedBox.shrink();

        final media = MediaQuery.of(context);
        final screen = media.size;
        final safe = media.padding;
        final keyboard = media.viewInsets.bottom;
        final bottomLimit = screen.height - math.max(keyboard, safe.bottom);

        if (!terminal.expanded) {
          return Stack(
            children: [
              _buildBall(terminal, screen, safe, bottomLimit),
            ],
          );
        }

        return Stack(
          children: [
            Positioned.fromRect(
              rect: Rect.fromLTWH(
                0,
                safe.top,
                screen.width,
                math.max(0, bottomLimit - safe.top),
              ),
              child: _buildWindow(terminal),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBall(
    TerminalController terminal,
    Size screen,
    EdgeInsets safe,
    double bottomLimit,
  ) {
    final fallback = Offset(
      screen.width - _ballSize - _edge,
      bottomLimit * 0.62,
    );
    final offset = _clampBall(
      _ballOffset ?? fallback,
      screen,
      safe,
      bottomLimit,
    );

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onTap: () => unawaited(widget.manager.showTerminal()),
        onLongPress: () => unawaited(terminal.close()),
        onPanUpdate: (details) {
          setState(() {
            _ballOffset = _clampBall(
              (_ballOffset ?? offset) + details.delta,
              screen,
              safe,
              bottomLimit,
            );
          });
        },
        onPanEnd: (_) => unawaited(_saveBallOffset()),
        child: _TerminalBall(status: terminal.status),
      ),
    );
  }

  Widget _buildWindow(TerminalController terminal) {
    final hostName = widget.manager.activeHost?.name ?? AppL10n.t.terminal;
    final status = terminal.status;
    final banner = switch (status) {
      TerminalStatus.opening => _TerminalBanner(message: AppL10n.t.openingTerminal),
      TerminalStatus.closed => _TerminalBanner(
          message: AppL10n.t.terminalDisconnected,
          onRetry: () => unawaited(terminal.open()),
        ),
      TerminalStatus.error => _TerminalBanner(
          message: terminal.error ?? AppL10n.t.terminalError,
          onRetry: () => unawaited(terminal.open()),
        ),
      _ => null,
    };

    return Material(
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          FloatingWindowHeader(
            title: AppL10n.t.terminalTitle(hostName),
            accentColor: _statusColor(status),
            onMinimize: terminal.minimize,
            onClose: () => unawaited(terminal.close()),
            onReconnect: status == TerminalStatus.closed ||
                    status == TerminalStatus.error
                ? () => unawaited(terminal.open())
                : null,
            closeTooltip: AppL10n.t.closeTerminal,
          ),
          Expanded(
            child: TerminalViewHost(
              controller: terminal,
              banner: banner,
            ),
          ),
        ],
      ),
    );
  }

  Offset _clampBall(
    Offset offset,
    Size screen,
    EdgeInsets safe,
    double bottomLimit,
  ) {
    final minX = _edge;
    final maxX = math.max(minX, screen.width - _ballSize - _edge);
    final minY = safe.top + _edge;
    final maxY = math.max(minY, bottomLimit - _ballSize - _edge);
    return Offset(
      offset.dx.clamp(minX, maxX).toDouble(),
      offset.dy.clamp(minY, maxY).toDouble(),
    );
  }
}

Color _statusColor(TerminalStatus status) {
  return switch (status) {
    TerminalStatus.open => const Color(0xFF4CD964),
    TerminalStatus.opening => const Color(0xFFFFB020),
    _ => const Color(0xFFFF453A),
  };
}

class _TerminalBall extends StatelessWidget {
  const _TerminalBall({required this.status});

  final TerminalStatus status;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppL10n.t.terminal,
      button: true,
      child: Material(
        elevation: 10,
        color: const Color(0xFF1B1B1B),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: _ballSize,
          height: _ballSize,
          child: Stack(
            children: [
              const Center(
                child: Icon(Icons.terminal, color: Colors.white, size: 26),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _statusColor(status),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF1B1B1B),
                      width: 1.5,
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

class _TerminalBanner extends StatelessWidget {
  const _TerminalBanner({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2A1F1F),
      padding: const EdgeInsets.only(left: 10, right: 4),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            size: 14,
            color: Color(0xFFFFB020),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
          if (onRetry != null)
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
