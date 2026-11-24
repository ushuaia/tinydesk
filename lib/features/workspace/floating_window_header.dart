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
    this.onClose,
    this.closeTooltip,
    this.onMinimize,
    this.onReconnect,
    this.accentColor,
    this.leadingIcon,
    this.leadingInset = 0,
  });

  static const height = 40.0;

  /// Space kept clear at the left edge for the macOS traffic lights when
  /// the system title bar is merged into the Flutter surface.
  final double leadingInset;

  final String title;
  final VoidCallback? onClose;
  final String? closeTooltip;
  final VoidCallback? onMinimize;
  final VoidCallback? onReconnect;

  /// Colored status dot (terminal state); wins over [leadingIcon].
  final Color? accentColor;

  /// Static leading icon (file browser); used when [accentColor] is null.
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    // Fixed light-grey strip over the dark terminal body, independent of the
    // app theme so the strip stays readable on both themes. The left inset
    // keeps clear of the macOS traffic lights.
    return Container(
      height: height,
      padding: EdgeInsets.only(left: leadingInset),
      color: const Color(0xFFECECEC),
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
            Icon(leadingIcon, size: 14, color: const Color(0xFF444444)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF1A1A1A),
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
          if (onClose != null)
            _HeaderButton(
              icon: Icons.close,
              tooltip: closeTooltip ?? AppL10n.t.close,
              onPressed: onClose!,
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
            child: Icon(icon, size: 18, color: const Color(0xFF444444)),
          ),
        ),
      ),
    );
  }
}
