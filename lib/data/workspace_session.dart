/// Rules the workspace relies on when reusing a WebView session. Kept pure so
/// the regressions we hit (wrong port's cookie, one-time link persisted as a
/// restore target) stay locked by tests.
library;

/// Picks the session cookie that belongs to [port] from the shared WebView
/// cookie jar. Cookies are named `opencode_session_<port>`; the prefix
/// fallback only guards against a future rename, never against a mismatch.
MapEntry<String, String>? pickSessionCookie(
  Map<String, String> cookies,
  int port,
) {
  final exact = cookies['opencode_session_$port'];
  if (exact != null && exact.isNotEmpty) {
    return MapEntry('opencode_session_$port', exact);
  }
  for (final entry in cookies.entries) {
    if (entry.key.startsWith('opencode_session_') && entry.value.isNotEmpty) {
      return entry;
    }
  }
  return null;
}

/// Whether [url] may be restored as this host's page. The pairing link is
/// one-time and must never be persisted or replayed.
bool isRestorableUrl(String? url, int port) {
  if (url == null) return false;
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.host != '127.0.0.1') return false;
  if (uri.port != port) return false;
  if (!uri.path.startsWith('/')) return false;
  if (uri.path.startsWith('/auth/connect')) return false;
  return true;
}
