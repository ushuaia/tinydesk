import 'host.dart';

/// Assigns each host a distinct local tunnel port.
///
/// opencode names its session cookie after the port it was paired through
/// (`opencode_session_<port>`), so different ports mean different cookie
/// names — sessions from different hosts coexist instead of overwriting
/// each other, and switching hosts does not require clearing any data.
class PortAllocator {
  const PortAllocator();

  /// Smallest free port at or above [start] that no host in [hosts] uses.
  int nextAvailable(List<Host> hosts, {int start = 49375}) {
    final used = hosts.map((h) => h.localPort).toSet();
    var port = start;
    while (used.contains(port)) {
      port++;
    }
    return port;
  }
}
