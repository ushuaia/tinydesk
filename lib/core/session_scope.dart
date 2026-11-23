import 'package:flutter/widgets.dart';

import '../session/app_session_manager.dart';

class SessionScope extends InheritedNotifier<AppSessionManager> {
  const SessionScope({
    super.key,
    required AppSessionManager manager,
    required super.child,
  }) : super(notifier: manager);

  static AppSessionManager of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope not found in widget tree');
    return scope!.notifier!;
  }

  static AppSessionManager read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope not found in widget tree');
    return scope!.notifier!;
  }
}
