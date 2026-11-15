import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../data/host.dart';
import '../../data/host_repository.dart';
import '../../data/key_generator.dart';
import '../../data/private_key_store.dart';
import '../../platform/private_key_picker.dart';

class HostFormPage extends StatefulWidget {
  const HostFormPage({
    super.key,
    this.repository,
    this.keyStore,
    this.keyPicker = const PrivateKeyPicker(),
    this.keyGenerator = const KeyGenerator(),
    this.initialHost,
    this.onSaved,
  });

  final HostRepository? repository;
  final PrivateKeyStore? keyStore;
  final PrivateKeyPicker keyPicker;
  final KeyGenerator keyGenerator;
  final Host? initialHost;
  final ValueChanged<Host>? onSaved;

  @override
  State<HostFormPage> createState() => _HostFormPageState();
}

class _HostFormPageState extends State<HostFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '22');
  final _username = TextEditingController();
  final _privateKey = TextEditingController();
  final _passphrase = TextEditingController();
  String? _keyError;
  String? _generatedPublicKey;
  bool _saving = false;
  bool _isLocal = false;

  bool get _isEditing => widget.initialHost != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.initialHost;
    if (existing != null) {
      _name.text = existing.name;
      _host.text = existing.host;
      _port.text = existing.port.toString();
      _username.text = existing.username;
      _isLocal = existing.isLocal;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _privateKey.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _portValidator(String? value) {
    final port = int.tryParse(value ?? '');
    if (port == null || port <= 0 || port > 65535) return '端口无效';
    return null;
  }

  Future<void> _pickPrivateKey() async {
    try {
      final text = await widget.keyPicker.pick();
      if (!mounted || text == null) return;
      setState(() {
        _privateKey.text = text;
        _keyError = null;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('读取文件失败：$error')));
      }
    }
  }

  Future<void> _copyPublicKey() async {
    final key = _generatedPublicKey;
    if (key == null) return;
    await Clipboard.setData(ClipboardData(text: key));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('公钥已复制')),
      );
    }
  }

  Future<void> _generateKey() async {
    final defaultComment =
        'tinydesk@${_host.text.trim().isEmpty ? 'host' : _host.text.trim()}';
    final controller = TextEditingController(text: defaultComment);
    final comment = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('生成新密钥'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('公钥注释会显示在 authorized_keys 里，方便以后识别。'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: '公钥注释'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('生成'),
          ),
        ],
      ),
    );
    if (comment == null || !mounted) return;

    try {
      final key = await widget.keyGenerator.generate(comment: comment);
      if (!mounted) return;
      setState(() {
        _privateKey.text = key.privateKeyPem;
        _generatedPublicKey = key.publicKey;
        _keyError = null;
      });
      var copied = false;
      try {
        await Clipboard.setData(ClipboardData(text: key.publicKey));
        copied = true;
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(copied ? '密钥已生成，公钥已复制' : '密钥已生成'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成密钥失败：$error')),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _keyError = null);
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请检查表单中的错误')));
      return;
    }

    final existing = widget.initialHost;
    final passphrase = _passphrase.text.isEmpty ? null : _passphrase.text;
    final privateKeyText = _privateKey.text.trim();
    final keepExistingKey = existing != null && privateKeyText.isEmpty;

    if (!_isLocal) {
      if (!keepExistingKey &&
          !PrivateKeyStore.isValidKey(_privateKey.text, passphrase)) {
        setState(() {
          _keyError = '无法识别的私钥格式，请使用 OpenSSH 格式（不支持 .ppk）';
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('私钥格式无法识别')));
        return;
      }
    }

    setState(() => _saving = true);
    final id = existing?.id ?? const Uuid().v4();
    final host = Host(
      id: id,
      name: _name.text.trim().isEmpty
          ? (_isLocal ? '本机' : _host.text.trim())
          : _name.text.trim(),
      type: _isLocal ? 'local' : 'ssh',
      host: _isLocal ? '127.0.0.1' : _host.text.trim(),
      port: _isLocal ? 22 : int.parse(_port.text),
      username: _isLocal ? Platform.environment['USER'] ?? 'me' : _username.text.trim(),
      privateKeyRef: _isLocal
          ? null
          : existing?.privateKeyRef ?? 'host.$id.privateKey',
      hasPassphrase: _isLocal
          ? false
          : (keepExistingKey ? existing.hasPassphrase : passphrase != null),
      remotePort: existing?.remotePort ?? 49374,
      localPort: existing?.localPort ?? 49375,
      autoStartServer: true,
      knownHostFingerprint: existing?.knownHostFingerprint,
      lastConnectedAt: existing?.lastConnectedAt,
    );

    try {
      if (widget.repository != null && widget.keyStore != null) {
        if (!_isLocal && !keepExistingKey) {
          await widget.keyStore!.save(id, _privateKey.text, passphrase);
        }
        await widget.repository!.upsert(host);
      }
      widget.onSaved?.call(host);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '编辑主机' : '添加主机')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: '名称（可选）',
                  hintText: '例如：开发机',
                ),
              ),
              const SizedBox(height: 12),
              if (_isLocal)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    '本机主机：直连本机 opencode 服务，无需配置连接参数',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              if (!_isLocal) ...[
              TextFormField(
                controller: _host,
                decoration: const InputDecoration(
                  labelText: '主机地址',
                  hintText: 'IP 或域名',
                ),
                validator: (v) => _required(v, '请输入主机地址'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _port,
                decoration: const InputDecoration(labelText: 'SSH 端口'),
                keyboardType: TextInputType.number,
                validator: _portValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(labelText: '用户名'),
                validator: (v) => _required(v, '请输入用户名'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _privateKey,
                decoration: InputDecoration(
                  labelText: 'OpenSSH 私钥',
                  hintText: _isEditing
                      ? '留空表示不修改已保存的私钥'
                      : '-----BEGIN OPENSSH PRIVATE KEY-----',
                  errorText: _keyError,
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                validator: (v) {
                  if (_isEditing && (v == null || v.trim().isEmpty)) {
                    return null;
                  }
                  return _required(v, '请粘贴 OpenSSH 私钥');
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _pickPrivateKey,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('从文件导入'),
                  ),
                  TextButton.icon(
                    onPressed: _generateKey,
                    icon: const Icon(Icons.key, size: 18),
                    label: const Text('生成密钥'),
                  ),
                ],
              ),
              if (_generatedPublicKey != null) ...[
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '公钥（已复制到剪贴板）',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _generatedPublicKey!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '把公钥追加到主机 ~/.ssh/authorized_keys',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _copyPublicKey,
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('复制公钥'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              TextFormField(
                controller: _passphrase,
                decoration: const InputDecoration(labelText: '私钥口令（可选）'),
                obscureText: true,
              ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '保存中…' : '保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
