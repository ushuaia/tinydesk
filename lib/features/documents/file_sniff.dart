import 'dart:math' as math;

/// Binary detection shared by the explorer (before opening a tab) and the
/// text viewer (while loading): a NUL byte in the first chunk is the reliable
/// signal. Control-character density is deliberately not used — UTF-16 and
/// legacy encodings would trip it and look binary.
bool looksBinary(List<int> bytes) {
  final limit = math.min(bytes.length, 8192);
  for (var index = 0; index < limit; index++) {
    if (bytes[index] == 0) return true;
  }
  return false;
}
