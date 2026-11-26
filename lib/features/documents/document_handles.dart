import 'package:flutter/material.dart';

import '../../core/app_language.dart';


import '../../data/remote_file.dart';
import '../../ssh/tunnel_session.dart';
import 'document_handle.dart';
import 'image_reader_page.dart';
import 'markdown_reader_page.dart';
import 'office_reader_page.dart';
import 'pdf_reader_page.dart';
import 'text_document_view.dart';

/// Builds the content handle for a file: dedicated readers for markdown,
/// PDF, office and images; the text viewer for everything else.
DocumentHandle? createDocumentHandle({
  required TunnelSession session,
  required RemoteFile file,
  required String hostId,
  required String projectRoot,
  String userScope = '',
}) {
  if (file.isMarkdown) {
    return MarkdownDocumentHandle(
      session: session,
      file: file,
      hostId: hostId,
      projectRoot: projectRoot,
      userScope: userScope,
    );
  }
  if (file.isPdf) {
    return PdfDocumentHandle(
      session: session,
      file: file,
      hostId: hostId,
      projectRoot: projectRoot,
      userScope: userScope,
    );
  }
  if (file.isCsv || file.isSpreadsheet || file.isWord) {
    return OfficeDocumentHandle(session: session, file: file);
  }
  if (file.isImage) {
    return ImageDocumentHandle(session: session, file: file);
  }
  // Everything else opens in the text viewer. Binary content is rejected by
  // the caller's sniff before a tab is created, so this does not depend on
  // an extension allow-list.
  return TextDocumentHandle(
    controller: TextDocumentController(session: session, file: file),
  );
}

class MarkdownDocumentHandle extends DocumentHandle {
  MarkdownDocumentHandle({
    required this.session,
    required this.file,
    required this.hostId,
    required this.projectRoot,
    this.userScope = '',
  });

  final TunnelSession session;
  final RemoteFile file;
  final String hostId;
  final String projectRoot;
  final String userScope;
  final GlobalKey<MarkdownReaderPageState> key =
      GlobalKey<MarkdownReaderPageState>();

  MarkdownReaderPageState? _state;

  /// Called by the embedded page on mount (via GlobalKey timing).
  void register(MarkdownReaderPageState state) => _state = state;

  @override
  String get title => file.name;

  @override
  bool get dirty => _state?.isDirty ?? false;

  @override
  Future<bool> checkExternalUpdate() => _state?.checkExternalUpdate() ?? Future.value(false);

  @override
  Future<void> reloadExternalChanges() async {
    await _state?.reloadFromServer();
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    final state = _state;
    final editing = state?.isEditing ?? false;
    final wide = MediaQuery.of(context).size.width >= 700;
    return [
      if (dirty)
        IconButton(
          onPressed: () async {
            await _state?.saveDocument();
          },
          icon: const Icon(Icons.save_outlined),
          iconSize: 18,
          tooltip: AppL10n.t.save,
        ),
      IconButton(
        onPressed: () {
          try {
            _state?.toggleEditMode();
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppL10n.t.toggleEditFailed(error.toString()))),
              );
            }
          }
        },
        icon: Icon(
          editing ? Icons.visibility_outlined : Icons.edit_outlined,
        ),
        iconSize: 18,
        tooltip: editing ? AppL10n.t.reading : AppL10n.t.edit,
      ),
      if (!editing && state != null && wide) ...[
        IconButton(
          onPressed: () => _state?.zoomBy(-0.1),
          icon: const Icon(Icons.text_decrease),
          iconSize: 18,
          tooltip: AppL10n.t.zoomOutFont,
        ),
        IconButton(
          onPressed: () => _state?.zoomBy(0.1),
          icon: const Icon(Icons.text_increase),
          iconSize: 18,
          tooltip: AppL10n.t.zoomInFont,
        ),
      ],
    ];
  }

  @override
  Widget buildBody(BuildContext context) {
    return MarkdownReaderPage(
      key: key,
      register: register,
      session: session,
      file: file,
      hostId: hostId,
      projectRoot: projectRoot,
      userScope: userScope,
      embedded: true,
      onStateChanged: notifyListeners,
    );
  }

  @override
  Future<bool> confirmClose(BuildContext context) async {
    final state = _state;
    if (state == null || !state.isDirty) return true;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppL10n.t.unsavedChanges),
        content: Text(AppL10n.t.unsavedChangesFile(file.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(AppL10n.t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(AppL10n.t.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(AppL10n.t.save),
          ),
        ],
      ),
    );
    if (action == 'save') {
      await state.saveDocument();
      return !state.isDirty;
    }
    return action == 'discard';
  }

  @override
  Future<void> close() async {
    await _state?.flushProgress();
  }
}

class PdfDocumentHandle extends DocumentHandle {
  PdfDocumentHandle({
    required this.session,
    required this.file,
    required this.hostId,
    required this.projectRoot,
    this.userScope = '',
  });

  final TunnelSession session;
  final RemoteFile file;
  final String hostId;
  final String projectRoot;
  final String userScope;
  final GlobalKey<PdfReaderPageState> key = GlobalKey<PdfReaderPageState>();

  PdfReaderPageState? get _state => key.currentState;

  @override
  String get title => file.name;

  @override
  List<Widget> buildActions(BuildContext context) {
    final state = _state;
    if (state == null) return const [];
    if (MediaQuery.of(context).size.width < 700) return const [];
    return [
      IconButton(
        onPressed: () => state.zoomBy(-0.2),
        icon: const Icon(Icons.zoom_out),
        iconSize: 18,
        tooltip: AppL10n.t.zoomOut,
      ),
      IconButton(
        onPressed: () => state.zoomBy(0.2),
        icon: const Icon(Icons.zoom_in),
        iconSize: 18,
        tooltip: AppL10n.t.zoomIn,
      ),
    ];
  }

  @override
  Widget buildBody(BuildContext context) {
    return PdfReaderPage(
      key: key,
      session: session,
      file: file,
      hostId: hostId,
      projectRoot: projectRoot,
      userScope: userScope,
      embedded: true,
    );
  }

  @override
  Future<void> close() async {
    await _state?.flushProgress();
  }
}

class OfficeDocumentHandle extends DocumentHandle {
  OfficeDocumentHandle({required this.session, required this.file});

  final TunnelSession session;
  final RemoteFile file;

  @override
  String get title => file.name;

  @override
  Widget buildBody(BuildContext context) =>
      OfficeReaderPage(session: session, file: file, embedded: true);

  @override
  Future<void> close() async {}
}

class ImageDocumentHandle extends DocumentHandle {
  ImageDocumentHandle({required this.session, required this.file});

  final TunnelSession session;
  final RemoteFile file;

  @override
  String get title => file.name;

  @override
  Widget buildBody(BuildContext context) =>
      ImageReaderPage(session: session, file: file, embedded: true);

  @override
  Future<void> close() async {}
}
