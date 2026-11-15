import 'package:flutter/material.dart';

class ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ReaderAppBar({
    super.key,
    required this.title,
    required this.zoom,
    required this.onZoomOut,
    required this.onZoomIn,
    this.onBack,
    this.canZoomOut = true,
    this.canZoomIn = true,
    this.onToggleEdit,
    this.editing = false,
    this.onSave,
    this.dirty = false,
    this.showZoom = true,
  });

  final String title;
  final double zoom;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback? onBack;
  final bool canZoomOut;
  final bool canZoomIn;
  final VoidCallback? onToggleEdit;
  final bool editing;
  final VoidCallback? onSave;
  final bool dirty;
  final bool showZoom;

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 40,
      leadingWidth: 40,
      leading: onBack == null
          ? null
          : IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: 40,
                height: 40,
              ),
              tooltip: '返回',
            ),
      titleTextStyle: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (dirty) ...[
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (dirty)
          IconButton(
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            visualDensity: VisualDensity.compact,
            tooltip: '保存',
          ),
        if (onToggleEdit != null)
          IconButton(
            onPressed: onToggleEdit,
            icon: Icon(
              editing ? Icons.visibility_outlined : Icons.edit_outlined,
            ),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            visualDensity: VisualDensity.compact,
            tooltip: editing ? '阅读' : '编辑',
          ),
        if (showZoom) ...[
          _ZoomButton(
            icon: Icons.remove,
            onPressed: canZoomOut ? onZoomOut : null,
          ),
          Text(
            '${(zoom * 100).round()}%',
            style: const TextStyle(fontSize: 11),
          ),
          _ZoomButton(
            icon: Icons.add,
            onPressed: canZoomIn ? onZoomIn : null,
          ),
        ],
        const SizedBox(width: 4),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      visualDensity: VisualDensity.compact,
    );
  }
}
