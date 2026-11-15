List<String> splitMarkdown(String text, {int maxChunk = 4000}) {
  final chunks = <String>[];
  final buffer = StringBuffer();
  var inCode = false;

  void flush() {
    if (buffer.isEmpty) return;
    chunks.add(buffer.toString());
    buffer.clear();
  }

  for (final line in text.split('\n')) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('```')) inCode = !inCode;
    final isHeading =
        !inCode && (trimmed.startsWith('# ') || trimmed.startsWith('## '));
    if (isHeading && buffer.isNotEmpty) flush();
    buffer.writeln(line);
    if (!inCode && buffer.length >= maxChunk) flush();
  }
  flush();
  return chunks;
}
