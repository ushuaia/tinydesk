import 'package:flutter/material.dart';
import '../../core/app_language.dart';


const _ballSize = 56.0;
const _edge = 12.0;

/// Ball + full-bleed window for the floating file browser.
///
/// The window subtree stays mounted while minimized ([Visibility] with
/// `maintainSize`), so open documents and unsaved edits survive. It also
/// carries its own [Navigator]: the shell is a sibling of the MaterialApp
/// navigator, so dialogs and menus opened by the page need one.
class FloatingFileBrowserShell extends StatelessWidget {
  const FloatingFileBrowserShell({
    super.key,
    required this.visible,
    required this.expanded,
    required this.ballOffset,
    required this.onBallTap,
    required this.onBallDragUpdate,
    required this.onBallDragEnd,
    required this.child,
    this.onBallLongPress,
  });

  final bool visible;
  final bool expanded;
  final Offset? ballOffset;
  final VoidCallback onBallTap;
  final VoidCallback? onBallLongPress;
  final ValueChanged<Offset> onBallDragUpdate;
  final VoidCallback onBallDragEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final media = MediaQuery.of(context);
    final bottomLimit = media.size.height - media.padding.bottom;
    final fallback = Offset(
      media.size.width - _ballSize - _edge,
      bottomLimit * 0.42,
    );
    final offset = ballOffset ?? fallback;

    return Stack(
      children: [
        Positioned.fromRect(
          rect: Rect.fromLTWH(
            0,
            media.padding.top,
            media.size.width,
            (bottomLimit - media.padding.top).clamp(0.0, double.infinity),
          ),
          child: Visibility(
            visible: expanded,
            maintainState: true,
            maintainSize: true,
            maintainAnimation: true,
            child: Material(child: _WindowNavigator(child: child)),
          ),
        ),
        if (!expanded)
          Positioned(
            left: offset.dx,
            top: offset.dy,
            child: GestureDetector(
              onTap: onBallTap,
              onLongPress: onBallLongPress,
              onPanUpdate: (details) => onBallDragUpdate(details.delta),
              onPanEnd: (_) => onBallDragEnd(),
              child: const _FileBall(),
            ),
          ),
      ],
    );
  }
}

/// Gives the window its own navigation stack so `showDialog` / `showMenu`
/// called from the page resolve against the window, not the app navigator
/// (which is an ancestor of this overlay).
class _WindowNavigator extends StatelessWidget {
  const _WindowNavigator({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Without `none`, the inner navigator would try to share the app's
    // HeroController and assert during the first frame.
    return HeroControllerScope.none(
      child: Navigator(
        pages: [
          MaterialPage<void>(
            key: const ValueKey('floating-file-browser'),
            child: child,
          ),
        ],
        onDidRemovePage: (_) {},
      ),
    );
  }
}

class _FileBall extends StatelessWidget {
  const _FileBall();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppL10n.t.filesTitle,
      button: true,
      child: Material(
        elevation: 10,
        color: const Color(0xFF1B1B1B),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: const SizedBox(
          width: _ballSize,
          height: _ballSize,
          child: Center(
            child: Icon(Icons.folder_open, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}
