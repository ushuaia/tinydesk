import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/connection_state.dart';
import '../connect/connect_page.dart';

/// One switchable session chip in the workspace toolbar.
class WorkspaceTab {
  const WorkspaceTab({
    required this.hostId,
    required this.name,
    required this.phase,
  });

  final String hostId;
  final String name;
  final ConnectionPhase phase;
}

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({
    super.key,
    this.title = '',
    required this.snapshot,
    this.onRetry,
    this.onBack,
    this.onFiles,
    this.onDocuments,
    this.onUpgrade,
    this.onTerminal,
    this.controller,
    this.tabs,
    this.activeHostId,
    this.onSelectTab,
    this.onCloseTab,
    this.onAddHost,
    this.body,
    this.showSessionActions = true,
  });

  final String title;
  final ConnectionSnapshot snapshot;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;
  final VoidCallback? onFiles;
  final VoidCallback? onDocuments;
  final VoidCallback? onUpgrade;
  final VoidCallback? onTerminal;
  final WebViewController? controller;

  /// Open sessions shown as switchable chips. When null the toolbar shows
  /// the legacy single [title] label.
  final List<WorkspaceTab>? tabs;
  final String? activeHostId;
  final ValueChanged<String>? onSelectTab;

  /// Long-press on a chip asks the owner to close that session.
  final ValueChanged<String>? onCloseTab;

  /// Opens the host picker (the "+" button after the session chips).
  final VoidCallback? onAddHost;

  /// Custom body (multi-session container); falls back to the legacy
  /// controller/connect rendering when null.
  final Widget? body;

  /// Toolbar visibility flags (hidden for the empty workspace state).
  final bool showSessionActions;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (onBack != null) {
          onBack!();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(child: _header(context)),
                        if (showSessionActions) ...[
                          const SizedBox(width: 4),
                          _FloatingButton(
                            icon: Icons.folder_open,
                            tooltip: '文件',
                            onPressed: onFiles,
                          ),
                          const SizedBox(width: 4),
                          _FloatingButton(
                            icon: Icons.star_border,
                            tooltip: '收藏',
                            onPressed: onDocuments,
                          ),
                          const SizedBox(width: 4),
                          _FloatingButton(
                            icon: Icons.system_update_alt,
                            tooltip: 'opencode 升级',
                            onPressed: onUpgrade,
                          ),
                          const SizedBox(width: 4),
                          _FloatingButton(
                            icon: Icons.terminal,
                            tooltip: '终端',
                            onPressed: onTerminal,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: body ?? _body(context)),
                  if (snapshot.phase == ConnectionPhase.reconnecting)
                    const Positioned.fill(child: _ReconnectOverlay()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pseudo tab id used when the host navigation module is the active page.
  static const newTabHostId = '__new_tab__';

  Widget _header(BuildContext context) {
    final tabs = this.tabs;
    final newTabActive = activeHostId == newTabHostId;
    if (tabs == null || tabs.isEmpty) {
      if (!newTabActive && onAddHost == null) {
        if (title.isEmpty) return const SizedBox.shrink();
        return _HostChip(title: title);
      }
      return Align(
        alignment: Alignment.centerLeft,
        child: _NewTabChip(
          active: newTabActive,
          onOpen: onAddHost,
        ),
      );
    }
    // Chrome-style flat tab strip: tabs separated by thin dividers and the
    // "new tab" chip trailing the last tab inside the scrollable strip.
    // Dividers touching the selected tab are hidden.
    final activeIndex = newTabActive
        ? -1
        : tabs.indexWhere((tab) => tab.hostId == activeHostId);
    bool sessionActive(int index) => index == activeIndex;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < tabs.length; index++) ...[
            if (index > 0 &&
                !sessionActive(index - 1) &&
                !sessionActive(index))
              const _TabDivider(),
            _SessionChip(
              tab: tabs[index],
              active: sessionActive(index),
              onTap: onSelectTab == null
                  ? null
                  : () => onSelectTab!(tabs[index].hostId),
              onClose: onCloseTab == null
                  ? null
                  : () => onCloseTab!(tabs[index].hostId),
            ),
          ],
          if (!newTabActive && !sessionActive(tabs.length - 1))
            const _TabDivider(),
          _NewTabChip(active: newTabActive, onOpen: onAddHost),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (snapshot.phase == ConnectionPhase.failed) {
      return _ErrorView(message: snapshot.message ?? '连接失败', onRetry: onRetry);
    }
    if (controller != null) {
      return WebViewWidget(controller: controller!);
    }
    if (snapshot.phase == ConnectionPhase.reconnecting) {
      return const SizedBox.shrink();
    }
    return ConnectView(snapshot: snapshot);
  }
}

class _FloatingButton extends StatelessWidget {
  const _FloatingButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _HostChip extends StatelessWidget {
  const _HostChip({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SessionChip extends StatelessWidget {
  const _SessionChip({
    required this.tab,
    required this.active,
    this.onTap,
    this.onClose,
  });

  final WorkspaceTab tab;
  final bool active;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  Color _phaseColor(BuildContext context) {
    return switch (tab.phase) {
      ConnectionPhase.ready => const Color(0xFF4CD964),
      ConnectionPhase.failed => const Color(0xFFFF453A),
      ConnectionPhase.reconnecting ||
      ConnectionPhase.sshConnecting ||
      ConnectionPhase.authenticating ||
      ConnectionPhase.tunneling ||
      ConnectionPhase.probing ||
      ConnectionPhase.startingServer ||
      ConnectionPhase.pairing =>
        const Color(0xFFFFB020),
      ConnectionPhase.idle => const Color(0xFF8E8E93),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = active ? scheme.onSurface : scheme.onSurfaceVariant;
    return Semantics(
      label: '切换到 ${tab.name}',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.only(left: 10, right: 2),
          decoration: active
              ? BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Connection status acts as the tab's "favicon".
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _phaseColor(context),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  tab.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (onClose != null) ...[
                const SizedBox(width: 2),
                Semantics(
                  label: '关闭 ${tab.name}',
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onClose,
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabDivider extends StatelessWidget {
  const _TabDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _NewTabChip extends StatelessWidget {
  const _NewTabChip({required this.active, this.onOpen});

  final bool active;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!active) {
      return Semantics(
        label: '打开主机',
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onOpen,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              Icons.add,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    // Active new-tab page: flat like a regular tab, with the + inside.
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 10, right: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.dashboard_outlined,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '新标签页',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            label: '打开主机',
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onOpen,
              child: SizedBox(
                width: 24,
                height: 24,
                child: Icon(
                  Icons.add,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _ReconnectOverlay extends StatelessWidget {
  const _ReconnectOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                '网络中断，正在重连…',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
