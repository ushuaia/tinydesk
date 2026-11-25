import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:tinydesk/core/ball_snap.dart';

void main() {
  const screen = Size(1440, 900);
  final safe = EdgeInsets.zero;

  test('a ball released on the right half snaps to the right edge', () {
    final snapped = snapBallToEdge(const Offset(1200, 400), screen, safe, 56);
    expect(snapped.dx, 1440 - 56 - 12);
    expect(snapped.dy, 400);
  });

  test('a ball released on the left half snaps to the left edge', () {
    final snapped = snapBallToEdge(const Offset(200, 400), screen, safe, 56);
    expect(snapped.dx, 12);
    expect(snapped.dy, 400);
  });

  test('the vertical position is clamped into the window', () {
    final snapped = snapBallToEdge(const Offset(1200, 5000), screen, safe, 56);
    expect(snapped.dy, 900 - 56 - 12);
  });
}
