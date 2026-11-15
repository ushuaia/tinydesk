import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/app_session_manager.dart';
import '../../data/app_settings.dart';
import '../../data/host_repository.dart';
import '../../data/local_data_cleaner.dart';
import '../../data/private_key_store.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../platform/background_task.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.repository,
    required this.keyStore,
    required this.language,
    this.manager,
  });

  final HostRepository repository;
  final PrivateKeyStore keyStore;
  final AppLanguageController language;
  final AppSessionManager? manager;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settings = AppSettings();
  bool _darkMode = false;
  bool _keepAlive = true;
  bool _autoBlurKeyboard = true;
  double _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    _settings.autoBlurKeyboard().then((value) {
      if (mounted) setState(() => _autoBlurKeyboard = value);
    });
  }

  Future<void> _confirmClear(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearDataConfirmTitle),
        content: Text(l10n.clearDataConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final cleaner = LocalDataCleaner(
      repository: widget.repository,
      keyStore: widget.keyStore,
      manager: widget.manager,
    );
    try {
      await cleaner.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.dataCleared)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.clearFailed(error.toString()))),
      );
    }
  }

  Future<void> _chooseLanguage(AppLocalizations l10n) async {
    final choice = await showDialog<AppLanguage>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          RadioGroup<AppLanguage>(
            groupValue: widget.language.value,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              children: [
                for (final option in AppLanguage.values)
                  RadioListTile<AppLanguage>(
                    value: option,
                    title: Text(switch (option) {
                      AppLanguage.system => l10n.followSystem,
                      AppLanguage.chinese => l10n.chinese,
                      AppLanguage.english => l10n.english,
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (choice == null || choice == widget.language.value) return;
    await widget.language.set(choice);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.languageUpdated)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(l10n.appearanceSection),
            SwitchListTile(
              value: _darkMode,
              onChanged: (v) => setState(() => _darkMode = v),
              title: Text(l10n.darkMode),
            ),
            ListTile(
              title: Text(l10n.fontScale),
              subtitle: Slider(
                value: _fontScale,
                min: 0.8,
                max: 1.4,
                divisions: 6,
                label: '${(_fontScale * 100).round()}%',
                onChanged: (v) => setState(() => _fontScale = v),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.language),
              subtitle: Text(switch (widget.language.value) {
                AppLanguage.system => l10n.followSystem,
                AppLanguage.chinese => l10n.chinese,
                AppLanguage.english => l10n.english,
              }),
              onTap: () => unawaited(_chooseLanguage(l10n)),
            ),
            const Divider(),
            _SectionHeader(l10n.connectionSection),
            SwitchListTile(
              value: _keepAlive,
              onChanged: (v) => setState(() => _keepAlive = v),
              title: Text(l10n.keepAlive),
              subtitle: Text(l10n.keepAliveSubtitle),
            ),
            SwitchListTile(
              value: _autoBlurKeyboard,
              onChanged: (v) {
                setState(() => _autoBlurKeyboard = v);
                _settings.setAutoBlurKeyboard(v);
              },
              title: Text(l10n.autoBlurKeyboard),
              subtitle: Text(l10n.autoBlurKeyboardSubtitle),
            ),
            ValueListenableBuilder<BackgroundTaskStatus>(
              valueListenable: BackgroundTask.status,
              builder: (context, status, _) => ListTile(
                title: Text(l10n.backgroundTask),
                subtitle: Text(status.message),
              ),
            ),
            const Divider(),
            _SectionHeader(l10n.dataSection),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.clearData),
              subtitle: Text(l10n.clearDataSubtitle),
              onTap: () => unawaited(_confirmClear(l10n)),
            ),
            const Divider(),
            _SectionHeader(l10n.aboutSection),
            ListTile(
              title: Text(l10n.appName),
              subtitle: Text(l10n.appVersion),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
