import 'package:flutter/material.dart';

import '../../data/remote_file.dart';
import 'document_handle.dart';

/// Small presentation pieces extracted from the file browser page, which had
/// grown past 1300 lines. They are stateless and dependency-free.

class ActionDivider extends StatelessWidget {
  const ActionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 13,
      child: Center(
        child: Container(
          width: 1,
          height: 20,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class TreeDragBar extends StatelessWidget {
  const TreeDragBar({super.key, required this.onDrag, required this.onDragEnd});

  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd(),
        child: Container(
          width: 5,
          color: scheme.outlineVariant,
        ),
      ),
    );
  }
}

/// Breadcrumb trail for the current directory. `labels` holds display text;
/// the last entry is highlighted as the current location.
class BreadcrumbsBar extends StatelessWidget {
  const BreadcrumbsBar({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 38,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // long paths start at the current (rightmost) level
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    '›',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Text(
                labels[index],
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: index == labels.length - 1
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: index == labels.length - 1
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Title row of an open document: icon, name, dirty dot and read-only chip.
class DocumentTitleBar extends StatelessWidget {
  const DocumentTitleBar({
    super.key,
    required this.doc,
    required this.icon,
  });

  final DocumentHandle doc;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            doc.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        if (doc.dirty) ...[
          const SizedBox(width: 6),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
        if (doc.readOnlyReason != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              doc.readOnlyReason!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}

IconData iconForFileTitle(String title) =>
    iconForRemoteFile(RemoteFile(name: title, path: title, isDirectory: false));

IconData iconForRemoteFile(RemoteFile file) {
  if (file.isDirectory) return Icons.folder;
  if (file.isMarkdown) return Icons.description;
  if (file.isPdf) return Icons.picture_as_pdf;
  if (file.isImage) return Icons.image;
  if (file.isText) return Icons.code;
  return Icons.insert_drive_file;
}
