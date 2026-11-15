import 'package:flutter/material.dart';
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
        title: const Text('方寸台'),
        actions: [
          if (onImport != null)
            IconButton(
              onPressed: onImport,
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: '导入主机',
            ),
          if (onSettings != null)
            IconButton(
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined),
              tooltip: '设置',
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
              '主机',
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
                label: const Text('添加主机'),
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
              '方寸台',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '远程 opencode 工作台 · 点击主机开始会话',
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
                              '本机',
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
                      local ? '本机直连 · 无需 SSH' : '${host.username}@${host.host}',
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
                  const PopupMenuItem(value: 'edit', child: Text('编辑')),
                  if (!local) ...[
                    const PopupMenuItem(
                      value: 'exportQr',
                      child: Text('显示主机二维码'),
                    ),
                    const PopupMenuItem(
                      value: 'exportKey',
                      child: Text('导出私钥'),
                    ),
                    const PopupMenuItem(
                      value: 'exportPublicKey',
                      child: Text('导出公钥'),
                    ),
                  ],
                  if (open)
                    const PopupMenuItem(
                      value: 'disconnect',
                      child: Text('断开连接'),
                    ),
                  if (!local) ...[
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'delete', child: Text('删除')),
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
              '还没有主机',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '添加一台 SSH 主机开始使用；macOS 上也可直接使用内置「本机」。',
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
              label: const Text('添加第一台主机'),
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
                  '快速上手',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '① 连接前准备',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              '目标主机必须安装 opencode V2。方寸台是它的远程界面，会话、文件、终端能力都来自目标主机上的 opencode。',
              style: small,
            ),
            const SizedBox(height: 10),
            const _CommandLine('brew install opencode'),
            const SizedBox(height: 6),
            const _CommandLine('npm install -g @opencode/cli'),
            const SizedBox(height: 10),
            Text(
              '安装后执行 opencode --version，显示 2.x 即成功；旧版本可用 opencode upgrade --major 升级。Windows 建议在 WSL 中使用。',
              style: small,
            ),
            const _QuickStartDivider(),
            Text(
              '② 打开会话',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              '本机：macOS 上无需 SSH，直接点「本机」卡片即可，会自动发现并启动 opencode 服务。\n'
              '远程主机：点「添加主机」，填写 SSH 地址、端口、用户名和私钥，保存后点击卡片连接。',
              style: small,
            ),
            const _QuickStartDivider(),
            Text(
              '③ 切换与关闭',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              '顶部标签切换已打开的主机；标签内的 × 关闭该主机会话，只影响这一台。关闭最后一个标签后回到本页，点 + 随时打开新主机。',
              style: small,
            ),
            const _QuickStartDivider(),
            Text(
              '④ 工具栏',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              '文件：浏览当前主机目录，打开 md / pdf / csv / xlsx / docx。\n'
              '文档：最近打开的文档，继续上次阅读位置。\n'
              '终端：当前主机的 shell（本机终端暂未支持）。',
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
            tooltip: '复制命令',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: command));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('命令已复制')),
              );
            },
          ),
        ],
      ),
    );
  }
}
