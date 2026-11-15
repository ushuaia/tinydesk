class RemoteFile {
  const RemoteFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modifiedAt,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? modifiedAt;

  String get extension {
    final index = name.lastIndexOf('.');
    if (index <= 0) return '';
    return name.substring(index + 1).toLowerCase();
  }

  bool get isMarkdown => extension == 'md' || extension == 'markdown';
  bool get isPdf => extension == 'pdf';
  bool get isCsv => extension == 'csv';
  bool get isSpreadsheet => extension == 'xlsx' || extension == 'xls';
  bool get isWord => extension == 'docx';
  bool get isImage =>
      const {'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'}.contains(extension);
  bool get isText => const {
        'txt',
        'json',
        'yaml',
        'yml',
        'toml',
        'ini',
        'conf',
        'sh',
        'bash',
        'zsh',
        'js',
        'jsx',
        'ts',
        'tsx',
        'py',
        'go',
        'rs',
        'java',
        'kt',
        'c',
        'h',
        'cpp',
        'hpp',
        'cs',
        'rb',
        'php',
        'sql',
        'xml',
        'html',
        'css',
        'scss',
        'less',
        'dart',
        'swift',
        'lua',
        'vim',
        'log',
      }.contains(extension);
}
