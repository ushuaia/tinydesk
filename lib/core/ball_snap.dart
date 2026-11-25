import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Resting position of a floating ball when a drag ends.
///
/// The ball snaps to the nearer left or right edge of the window and keeps
/// its vertical position, so it never stays floating in the middle of the
/// screen or outside it.
Offset snapBallToEdge(
  Offset offset,
  Size screen,
  EdgeInsets safe,
  double ballSize, {
  double edge = 12,
}) {
  final maxY = math.max(
    safe.top + edge,
    screen.height - safe.bottom - ballSize - edge,
  );
  final y = offset.dy.clamp(safe.top + edge, maxY).toDouble();
  final centerX = offset.dx + ballSize / 2;
  final x = centerX < screen.width / 2
      ? edge
      : math.max(edge, screen.width - ballSize - edge);
  return Offset(x, y);
}
