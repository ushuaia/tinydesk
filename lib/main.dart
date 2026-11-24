import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'platform/diag_log.dart';
import 'data/host_store.dart';
import 'data/local_machine.dart';
import 'data/sandbox_migration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(DiagLog.write('app start'));
  // Turn stray async socket errors (peer resets on relays) into logged
  // non-fatal events instead of unhandled exceptions.
  // Freeze a copy of the original so the log mirror cannot recurse.
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    originalDebugPrint(message, wrapWidth: wrapWidth);
    if (message != null) unawaited(DiagLog.write(message));
  };
  // Uncaught async errors and widget-tree errors land in the exportable log.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('async error: $error');
    return true;
  };
  FlutterError.onError = (details) {
    originalDebugPrint('flutter error: ${details.exception}');
    unawaited(DiagLog.write(
      'flutter error: ${details.exception}\n${details.stack}',
    ));
    // Keep Flutter's default behaviour (error screen + console report):
    // swallowing it silently would hide real failures from the user.
    FlutterError.presentError(details);
  };
  // Must complete before any store reads SharedPreferences, so the
  // sandbox-era data lands before the UI renders the host list.
  try {
    final prefs = await SharedPreferences.getInstance();
    // Machines whose migration already completed carry stale sandbox-era
    // records that must not survive; machines just importing now keep data.
    final wasMigrated = prefs.getBool('sandbox.migrated.v1') ?? false;
    await const SandboxMigration().run();
    await const LegacyRecordCleanup()
        .run(prefs, allowed: wasMigrated);
    if (LocalMachine.supported) {
      await const LocalMachine()
          .ensure(SharedPreferencesHostStore());
    }
  } catch (_) {
    // Bootstrap failure must never block the app from starting.
  }
  runApp(const OpenCodeApp());
}
