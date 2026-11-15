import 'dart:convert';
import 'dart:typed_data';

import '../../core/app_language.dart';

/// Renders the {{viewer*}} placeholders inside the HTML viewer templates
/// using the strings for the current app language.
Uint8List renderViewerHtml(Uint8List asset) {
  var text = utf8.decode(asset, allowMalformed: true);
  final l = AppL10n.t;
  final values = {
    '{{viewerLoadFailedPrefix}}': l.viewerLoadFailedPrefix,
    '{{viewerLoading}}': l.viewerLoading,
    '{{viewerUnsupportedPrefix}}': l.viewerUnsupportedPrefix,
    '{{viewerLoadingPdf}}': l.viewerLoadingPdf,
    '{{viewerPdfLoadFailedPrefix}}': l.viewerPdfLoadFailedPrefix,
  };
  for (final entry in values.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  return Uint8List.fromList(utf8.encode(text));
}
