import 'package:flutter/material.dart';

import '../../core/app_language.dart';

import 'package:flutter/services.dart';

import '../../data/host.dart';

class HostListPage extends StatelessWidget {
  const HostListPage({
    super.key,
    required this.hosts,
    this.activeHostId,
    this.openHostIds = const {},
    this.readyHostIds = const {},
    this.embedded = false,
    this.onAdd,
    this.onSettings,
    this.onImport,
    this.onOpen,
    this.onEdit,
    this.onDelete,
    this.onDisconnect,
    this.onExportKey,
    this.onExportPublicKey,
    this.onExportQr,
  });

  final List<Host> hosts;
  final String? activeHostId;

  /// Hosts with a live session (connection and/or terminal).
  final Set<String> openHostIds;

  /// Open hosts whose connection reached ready.
  final Set<String> readyHostIds;

  /// Embedded inside the workspace: no app bar, body only.
  final bool embedded;
  final VoidCallback? onAdd;
  final VoidCallback? onSettings;
  final VoidCallback? onImport;
  final ValueChanged<Host>? onOpen;
  final ValueChanged<Host>? onEdit;
  final ValueChanged<Host>? onDelete;
  final ValueChanged<Host>? onDisconnect;
  final ValueChanged<Host>? onExportKey;
  final ValueChanged<Host>? onExportPublicKey;

  /// Opens the export dialog for one host.
  final ValueChanged<Host>? onExportQr;

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const _PageHeader(),
        const SizedBox(height: 24),
        _hostsSection(context),
        const SizedBox(height: 28),
        const _QuickStartSection(),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(AppL10n.t.fangchitai),
        actions: [
          if (onImport != null)
            IconButton(
              onPressed: onImport,
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: AppL10n.t.importHost,
            ),
          if (onSettings != null)
            IconButton(
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined),
              tooltip: AppL10n.t.settings,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
    );
  }

  Widget _hostsSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.dns_outlined, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              AppL10n.t.hostTab,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Text(
              '(${hosts.length})',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            if (onAdd != null && hosts.isNotEmpty)
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppL10n.t.addHost),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (hosts.isEmpty)
          _EmptyState(onAdd: onAdd)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 620
                      ? 2
                      : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 96,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: hosts.length,
                itemBuilder: (context, index) => _hostCard(hosts[index]),
              );
            },
          ),
      ],
    );
  }

  Widget _hostCard(Host host) {
    final open = openHostIds.contains(host.id);
    return _HostCard(
      host: host,
      open: open,
      ready: readyHostIds.contains(host.id),
      active: activeHostId == host.id,
      onTap: onOpen == null ? null : () => onOpen!(host),
      onEdit: onEdit == null ? null : () => onEdit!(host),
      onDelete: onDelete == null ? null : () => onDelete!(host),
      onDisconnect: onDisconnect == null ? null : () => onDisconnect!(host),
      onExportKey: onExportKey == null ? null : () => onExportKey!(host),
      onExportPublicKey: onExportPublicKey == null
          ? null
          : () => onExportPublicKey!(host),
      onExportQr: onExportQr == null ? null : () => onExportQr!(host),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.dock_outlined, size: 26, color: scheme.primary),
            const SizedBox(width: 10),
            Text(
              AppL10n.t.fangchitai,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          AppL10n.t.emptyStateTitle,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({
    required this.host,
    required this.open,
    required this.ready,
    required this.active,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onDisconnect,
    this.onExportKey,
    this.onExportPublicKey,
    this.onExportQr,
  });

  final Host host;

  /// Has a live session (tunnel or terminal).
  final bool open;

  /// Live session reached the ready phase.
  final bool ready;

  /// Currently displayed session.
  final bool active;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDisconnect;
  final VoidCallback? onExportKey;
  final VoidCallback? onExportPublicKey;
  final VoidCallback? onExportQr;

  @override
  Widget build(BuildContext context) {
    final local = host.isLocal;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: active
            ? BorderSide(color: scheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            children: [
              Icon(
                local ? Icons.computer : Icons.terminal,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            host.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (local) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppL10n.t.thisMachine,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ],
                        if (open) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: ready
                                  ? const Color(0xFF4CD964)
                                  : const Color(0xFFFFB020),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      local ? AppL10n.t.localBadge : '${host.username}@${host.host}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'exportQr') onExportQr?.call();
                  if (value == 'exportKey') onExportKey?.call();
                  if (value == 'exportPublicKey') onExportPublicKey?.call();
                  if (value == 'delete') onDelete?.call();
                  if (value == 'disconnect') onDisconnect?.call();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text(AppL10n.t.edit)),
                  if (!local) ...[
                    PopupMenuItem(
                      value: 'exportQr',
                      child: Text(AppL10n.t.showHostQr),
                    ),
                    PopupMenuItem(
                      value: 'exportKey',
                      child: Text(AppL10n.t.exportKey),
                    ),
                    PopupMenuItem(
                      value: 'exportPublicKey',
                      child: Text(AppL10n.t.exportPublicKey),
                    ),
                  ],
                  if (open)
                    PopupMenuItem(
                      value: 'disconnect',
                      child: Text(AppL10n.t.disconnect),
                    ),
                  if (!local) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Text(AppL10n.t.delete)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.dns_outlined,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              AppL10n.t.noHostsYet,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              AppL10n.t.emptyStateHint,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(AppL10n.t.addFirstHost),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStartSection extends StatelessWidget {
  const _QuickStartSection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.5,
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  AppL10n.t.quickStart,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              AppL10n.t.step1Prepare,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              AppL10n.t.targetNeedsV2,
              style: small,
            ),
            const SizedBox(height: 10),
            const _CommandLine('brew install opencode'),
            const SizedBox(height: 6),
            const _CommandLine('npm install -g @opencode/cli'),
            const SizedBox(height: 10),
            Text(
              AppL10n.t.installHint,
              style: small,
            ),
            const _QuickStartDivider(),
            Text(
              AppL10n.t.step2Open,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              AppL10n.t.quickStartHostsHint,
              style: small,
            ),
            const _QuickStartDivider(),
            Text(
              AppL10n.t.step3Switch,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              AppL10n.t.tabHint,
              style: small,
            ),
            const _QuickStartDivider(),
            Text(
              AppL10n.t.step4Toolbar,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              '${AppL10n.t.toolbarFiles}\n'
              '${AppL10n.t.toolbarDocuments}\n'
              '${AppL10n.t.toolbarTerminal}',
              style: small,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStartDivider extends StatelessWidget {
  const _QuickStartDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(
        height: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class _CommandLine extends StatelessWidget {
  const _CommandLine(this.command);

  final String command;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 2, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              command,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            tooltip: AppL10n.t.copyCommand,
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: command));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppL10n.t.commandCopied)),
              );
            },
          ),
        ],
      ),
    );
  }
}
