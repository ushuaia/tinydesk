import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/host_store.dart';
import 'data/local_machine.dart';
import 'data/sandbox_migration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
