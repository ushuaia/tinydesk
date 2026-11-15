import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum BackgroundTaskState { idle, running, failed }

class BackgroundTaskStatus {
  const BackgroundTaskStatus(this.state, this.message);

  final BackgroundTaskState state;
  final String message;
}

class BackgroundTask {
  static const _channel = MethodChannel('opencode/background');

  static final status = ValueNotifier<BackgroundTaskStatus>(
    const BackgroundTaskStatus(BackgroundTaskState.idle, '未启动'),
  );

  Future<void> start() async {
    try {
      await _channel.invokeMethod<bool>('start');
      status.value = const BackgroundTaskStatus(
        BackgroundTaskState.running,
        '运行中',
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
    status.value = const BackgroundTaskStatus(
      BackgroundTaskState.idle,
      '已停止',
    );
  }

  Future<void> update() async {
    try {
      await _channel.invokeMethod<bool>('update');
      status.value = const BackgroundTaskStatus(
        BackgroundTaskState.running,
        '运行中',
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
