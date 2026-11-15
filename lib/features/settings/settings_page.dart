import 'package:flutter/material.dart';

import '../../core/app_session_manager.dart';
import '../../data/app_settings.dart';
import '../../data/host_repository.dart';
import '../../data/local_data_cleaner.dart';
import '../../data/private_key_store.dart';
import '../../platform/background_task.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.repository,
    required this.keyStore,
    this.manager,
  });

  final HostRepository repository;
  final PrivateKeyStore keyStore;
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

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除数据'),
        content: const Text('将删除所有主机配置和密钥，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
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
        const SnackBar(content: Text('数据已清除')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清除失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader('外观'),
            SwitchListTile(
              value: _darkMode,
              onChanged: (v) => setState(() => _darkMode = v),
              title: const Text('深色模式'),
            ),
            ListTile(
              title: const Text('字体缩放'),
              subtitle: Slider(
                value: _fontScale,
                min: 0.8,
                max: 1.4,
                divisions: 6,
                label: '${(_fontScale * 100).round()}%',
                onChanged: (v) => setState(() => _fontScale = v),
              ),
            ),
            const Divider(),
            const _SectionHeader('连接'),
            SwitchListTile(
              value: _keepAlive,
              onChanged: (v) => setState(() => _keepAlive = v),
              title: const Text('后台保活'),
              subtitle: const Text('切到后台时尽量维持 SSH 隧道'),
            ),
            SwitchListTile(
              value: _autoBlurKeyboard,
              onChanged: (v) {
                setState(() => _autoBlurKeyboard = v);
                _settings.setAutoBlurKeyboard(v);
              },
              title: const Text('进入会话时自动收起键盘'),
              subtitle: const Text('避免打开会话时自动弹出输入法'),
            ),
            ValueListenableBuilder<BackgroundTaskStatus>(
              valueListenable: BackgroundTask.status,
              builder: (context, status, _) => ListTile(
                title: const Text('长时任务'),
                subtitle: Text(status.message),
              ),
            ),
            const Divider(),
            const _SectionHeader('数据'),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('清除数据'),
              subtitle: const Text('删除所有主机和密钥'),
              onTap: _confirmClear,
            ),
            const Divider(),
            const _SectionHeader('关于'),
            const ListTile(
              title: Text('方寸台 TinyDesk'),
              subtitle: Text('v1.1.1'),
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
