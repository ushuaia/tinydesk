import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/favorite_store.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    super.key,
    required this.load,
    required this.onOpen,
    required this.onRemove,
    required this.onClear,
    this.subtitleFor,
    this.sync,
  });

  final Future<List<FavoriteDocument>> Function() load;
  final Future<void> Function(FavoriteDocument) onOpen;
  final Future<void> Function(FavoriteDocument) onRemove;
  final Future<void> Function() onClear;
  final String Function(FavoriteDocument)? subtitleFor;

  /// Optional cross-device sync; runs after the local list is shown.
  final Future<void> Function()? sync;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<List<FavoriteDocument>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.load();
    unawaited(_runSync());
  }

  void _reload() {
    setState(() => _items = widget.load());
    unawaited(_runSync());
  }

  Future<void> _runSync() async {
    final sync = widget.sync;
    if (sync == null) return;
    try {
      await sync();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _items = widget.load());
  }

  Future<void> _open(FavoriteDocument doc) async {
    await widget.onOpen(doc);
    if (mounted) _reload();
  }

  Future<void> _remove(FavoriteDocument doc) async {
    await widget.onRemove(doc);
    if (mounted) _reload();
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空收藏？'),
        content: const Text('只清除收藏记录，不会删除远端文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onClear();
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
          IconButton(
            onPressed: _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '清空收藏',
          ),
        ],
      ),
      body: FutureBuilder<List<FavoriteDocument>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('读取收藏失败：${snapshot.error}'),
              ),
            );
          }
          final items = snapshot.data ?? const <FavoriteDocument>[];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_border,
                    size: 48,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text('还没有收藏文件'),
                  const SizedBox(height: 6),
                  Text(
                    '在文件页打开文件后点 ☆ 即可收藏',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = items[index];
              final subtitle = widget.subtitleFor?.call(doc) ?? doc.path;
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                minLeadingWidth: 24,
                leading: Icon(
                  _iconFor(doc.kind),
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                title: Text(
                  doc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  onSelected: (value) {
                    if (value == 'remove') _remove(doc);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'remove',
                      child: Text('取消收藏'),
                    ),
                  ],
                ),
                onTap: () => _open(doc),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(String kind) {
    return switch (kind) {
      'markdown' => Icons.description,
      'pdf' => Icons.picture_as_pdf,
      'office' => Icons.table_chart,
      'image' => Icons.image,
      'text' => Icons.code,
      _ => Icons.insert_drive_file,
    };
  }
}
