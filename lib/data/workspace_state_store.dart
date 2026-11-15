import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last opencode page (session URL) per host so switching
/// tabs, reconnecting and restarting the app restore the same scene.
class WorkspaceStateStore {
  static const _urlPrefix = 'workspace.url.v1.';

  Future<String?> loadUrl(String hostId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_urlPrefix$hostId');
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUrl(String hostId, String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_urlPrefix$hostId', url);
    } catch (_) {}
  }

  Future<void> clearUrl(String hostId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_urlPrefix$hostId');
    } catch (_) {}
  }
}
