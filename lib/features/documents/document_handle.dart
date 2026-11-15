import 'package:flutter/material.dart';

/// A file opened in the unified files page.
///
/// Each document type (text/code, markdown, pdf, office, image) provides a
/// handle so the page can render a common header (title, dirty marker,
/// type-specific actions, close) and guard unsaved changes.
abstract class DocumentHandle extends ChangeNotifier {
  /// Context for dialogs raised by the handle itself.
  BuildContext? navigatorContext;

  String get title;

  bool get dirty => false;

  /// Why the document is read-only (shown as a badge); null means editable.
  String? get readOnlyReason => null;

  /// Extra icon buttons for the content header.
  List<Widget> buildActions(BuildContext context) => const [];

  Widget buildBody(BuildContext context);

  /// Returns true when it is safe to close (saved or discarded).
  Future<bool> confirmClose(BuildContext context) async => true;

  /// True when the file changed on the server since it was loaded. Only
  /// text-like documents implement this; binary viewers ignore external
  /// changes.
  Future<bool> checkExternalUpdate() async => false;

  /// Reloads the document content from the server after
  /// [checkExternalUpdate] reported a change.
  Future<void> reloadExternalChanges() async {}

  /// Releases WebViews, servers and progress polling.
  Future<void> close();
}
