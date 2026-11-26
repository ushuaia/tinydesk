import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One entry of an [AnchoredMenu]. A `null` label renders a group separator.
class AnchoredMenuItem {
  const AnchoredMenuItem({
    required this.label,
    this.subtitle,
    this.value,
    this.leading,
    this.trailing,
  });

  const AnchoredMenuItem.separator()
      : label = null,
        subtitle = null,
        value = null,
        leading = null,
        trailing = null;

  final String? label;
  final String? subtitle;
  final Object? value;
  final Widget? leading;
  final Widget? trailing;

  bool get isSeparator => label == null;
}

/// VSCode-style context menu, positioned relative to the trigger itself.
///
/// Rendering through a plain PopupMenuButton inside the floating window's
/// nested Navigator misplaced the panel, so the menu measures its anchor and
/// places itself: below the anchor, clamped to the overlay, flipped upward
/// when it would overflow the bottom. Long menus scroll within [maxHeight].
class AnchoredMenu {
  AnchoredMenu._();

  static Future<Object?> show({
    required BuildContext context,
    required Rect anchor,
    required List<AnchoredMenuItem> items,
    Object? selectedValue,
    double width = 240,
    double maxHeight = 460,
  }) async {
    final overlayRender = Overlay.of(context).context.findRenderObject();
    if (overlayRender is! RenderBox || !overlayRender.hasSize) return null;
    final overlaySize = overlayRender.size;

    var height = 12.0;
    for (final item in items) {
      height += item.isSeparator ? 9 : (item.subtitle == null ? 34 : 46);
    }
    final menuHeight = height.clamp(0.0, maxHeight);

    var top = anchor.bottom + 4;
    if (top + menuHeight > overlaySize.height - 8) {
      top = (anchor.top - menuHeight - 4).clamp(0.0, double.infinity);
    }
    final left = anchor.left
        .clamp(0.0, (overlaySize.width - width).clamp(0.0, double.infinity))
        .toDouble();

    final completer = Completer<Object?>();
    late final OverlayEntry entry;
    void close(Object? value) {
      if (!completer.isCompleted) completer.complete(value);
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () => close(null),
          },
          child: Focus(
            autofocus: true,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => close(null),
                  ),
                ),
                Positioned(
                  left: left,
                  top: top,
                  width: width,
                  child: Material(
                    elevation: 10,
                    shadowColor: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    color: scheme.surfaceContainerLowest,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxHeight),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final item in items)
                                if (item.isSeparator)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: scheme.outlineVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                  )
                                else
                                  InkWell(
                                    onTap: () => close(item.value),
                                    child: Container(
                                      height: item.subtitle == null ? 34 : 46,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        children: [
                                          if (item.leading != null) ...[
                                            item.leading!,
                                            const SizedBox(width: 10),
                                          ],
                                          Expanded(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.label!,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: scheme.onSurface,
                                                  ),
                                                ),
                                                if (item.subtitle != null)
                                                  Text(
                                                    item.subtitle!,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (item.trailing != null)
                                            item.trailing!,
                                        ],
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(entry);
    return completer.future;
  }
}
