import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/app_language.dart';


enum BackgroundTaskState { idle, running, failed }

class BackgroundTaskStatus {
  const BackgroundTaskStatus(this.state, this.message);

  final BackgroundTaskState state;
  final String message;
}

class BackgroundTask {
  static const _channel = MethodChannel('opencode/background');

  static final status = ValueNotifier<BackgroundTaskStatus>(
    BackgroundTaskStatus(BackgroundTaskState.idle, AppL10n.t.taskIdle),
  );

  Future<void> start() async {
    try {
      await _channel.invokeMethod<bool>('start');
      status.value = BackgroundTaskStatus(
        BackgroundTaskState.running,
        AppL10n.t.taskRunning,
      );
    } catch (error) {
      status.value = BackgroundTaskStatus(
        BackgroundTaskState.failed,
        '$error',
      );
      rethrow;
    }
  }

  Future<void> stop() async {
    await _channel.invokeMethod<bool>('stop');
    status.value = BackgroundTaskStatus(
      BackgroundTaskState.idle,
      AppL10n.t.taskStopped,
    );
  }

  Future<void> update() async {
    try {
      await _channel.invokeMethod<bool>('update');
      status.value = BackgroundTaskStatus(
        BackgroundTaskState.running,
        AppL10n.t.taskRunning,
      );
    } catch (error) {
      status.value = BackgroundTaskStatus(
        BackgroundTaskState.failed,
        '$error',
      );
      rethrow;
    }
  }
}
