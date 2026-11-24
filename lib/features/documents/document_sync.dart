/// What the document auto-sync should do after one poll.
enum DocSyncAction {
  /// Nothing to do, or the conflict notice was shown too recently.
  none,

  /// The document is clean and the server copy changed: reload it.
  reload,

  /// Unsaved edits are at risk: tell the user instead of reloading.
  conflict,
}

/// Decides how to react to an external change, throttling the conflict notice
/// so a repeatedly-changing file does not spam snackbars.
class DocSyncPolicy {
  DocSyncPolicy({this.noticeInterval = const Duration(minutes: 1)});

  final Duration noticeInterval;
  DateTime? _lastNotice;

  DocSyncAction decide({
    required bool changed,
    required bool dirty,
    required DateTime now,
  }) {
    if (!changed) return DocSyncAction.none;
    if (!dirty) return DocSyncAction.reload;
    final last = _lastNotice;
    if (last != null && now.difference(last) < noticeInterval) {
      return DocSyncAction.none;
    }
    _lastNotice = now;
    return DocSyncAction.conflict;
  }
}
