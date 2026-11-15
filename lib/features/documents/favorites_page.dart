import 'dart:async';
import '../../core/app_language.dart';

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
        title: Text(AppL10n.t.clearFavoritesTitle),
        content: Text(AppL10n.t.clearFavoritesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL10n.t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppL10n.t.clearAll),
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
        title: Text(AppL10n.t.favorite),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: AppL10n.t.refresh,
          ),
          IconButton(
            onPressed: _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: AppL10n.t.clearFavorites,
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
                child: Text(AppL10n.t.favoritesLoadFailed(snapshot.error.toString())),
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
                  Text(AppL10n.t.noFavorites),
                  const SizedBox(height: 6),
                  Text(
                    AppL10n.t.favoritesHint,
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
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(AppL10n.t.unfavorite),
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
