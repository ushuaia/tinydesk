import 'package:flutter/material.dart';


import '../../core/app_language.dart';



/// Shared 40px dark header for the floating terminal and file browser
/// windows: a status dot or icon, the title, and minimize/close buttons on
/// the right. Keeping it in one widget makes both overlays look and behave
/// identically.
class FloatingWindowHeader extends StatelessWidget {
  const FloatingWindowHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.closeTooltip,
    this.onMinimize,
    this.onReconnect,
    this.accentColor,
    this.leadingIcon,
  });

  static const height = 40.0;

  final String title;
  final VoidCallback onClose;
  final String? closeTooltip;
  final VoidCallback? onMinimize;
  final VoidCallback? onReconnect;

  /// Colored status dot (terminal state); wins over [leadingIcon].
  final Color? accentColor;

  /// Static leading icon (file browser); used when [accentColor] is null.
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    // Follow the app theme so both overlays match the surrounding chrome
    // instead of forcing a fixed dark strip.
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      color: scheme.surfaceContainerHighest,
      child: Row(
        children: [
          const SizedBox(width: 10),
          if (accentColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ] else if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onReconnect != null)
            _HeaderButton(
              icon: Icons.refresh,
              tooltip: AppL10n.t.reconnect,
              onPressed: onReconnect!,
            ),
          if (onMinimize != null)
            _HeaderButton(
              icon: Icons.remove,
              tooltip: AppL10n.t.minimize,
              onPressed: onMinimize!,
            ),
          _HeaderButton(
            icon: Icons.close,
            tooltip: closeTooltip ?? AppL10n.t.close,
            onPressed: onClose,
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: tooltip,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            color: Colors.transparent,
            child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
