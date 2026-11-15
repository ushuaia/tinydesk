import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import '../../core/app_language.dart';

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
    if (port == null || port <= 0 || port > 65535) return AppL10n.t.invalidPort;
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
            .showSnackBar(SnackBar(content: Text(AppL10n.t.readFileFailed(error.toString()))));
      }
    }
  }

  Future<void> _copyPublicKey() async {
    final key = _generatedPublicKey;
    if (key == null) return;
    await Clipboard.setData(ClipboardData(text: key));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.publicKeyCopied)),
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
        title: Text(AppL10n.t.generateNewKey),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppL10n.t.keyCommentHint),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(labelText: AppL10n.t.keyComment),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppL10n.t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(AppL10n.t.generate),
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
            content: Text(copied ? AppL10n.t.keyGeneratedCopied : AppL10n.t.keyGenerated),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.t.generateKeyFailed(error.toString()))),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _keyError = null);
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppL10n.t.checkFormErrors)));
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
          _keyError = AppL10n.t.unrecognizedKey;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppL10n.t.keyUnrecognized)));
        return;
      }
    }

    setState(() => _saving = true);
    final id = existing?.id ?? const Uuid().v4();
    final host = Host(
      id: id,
      name: _name.text.trim().isEmpty
          ? (_isLocal ? AppL10n.t.thisMachine : _host.text.trim())
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
            .showSnackBar(SnackBar(content: Text(AppL10n.t.saveFailed(error.toString()))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? AppL10n.t.editHost : AppL10n.t.addHost)),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: AppL10n.t.nameOptional,
                  hintText: AppL10n.t.nameHint,
                ),
              ),
              const SizedBox(height: 12),
              if (_isLocal)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    AppL10n.t.localFormHint,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              if (!_isLocal) ...[
              TextFormField(
                controller: _host,
                decoration: InputDecoration(
                  labelText: AppL10n.t.hostAddress,
                  hintText: AppL10n.t.hostAddressHint,
                ),
                validator: (v) => _required(v, AppL10n.t.enterHostAddress),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _port,
                decoration: InputDecoration(labelText: AppL10n.t.sshPort),
                keyboardType: TextInputType.number,
                validator: _portValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                decoration: InputDecoration(labelText: AppL10n.t.username),
                validator: (v) => _required(v, AppL10n.t.enterUsername),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _privateKey,
                decoration: InputDecoration(
                  labelText: AppL10n.t.openSshKey,
                  hintText: _isEditing
                      ? AppL10n.t.keyKeepHint
                      : '-----BEGIN OPENSSH PRIVATE KEY-----',
                  errorText: _keyError,
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                validator: (v) {
                  if (_isEditing && (v == null || v.trim().isEmpty)) {
                    return null;
                  }
                  return _required(v, AppL10n.t.pasteKey);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _pickPrivateKey,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: Text(AppL10n.t.importFromFile),
                  ),
                  TextButton.icon(
                    onPressed: _generateKey,
                    icon: const Icon(Icons.key, size: 18),
                    label: Text(AppL10n.t.generateKey),
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
                          AppL10n.t.publicKeyClipboard,
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
                            Expanded(
                              child: Text(
                                AppL10n.t.publicKeyUsage,
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _copyPublicKey,
                              icon: const Icon(Icons.copy, size: 16),
                              label: Text(AppL10n.t.copyPublicKey),
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
                decoration: InputDecoration(labelText: AppL10n.t.passphraseOptional),
                obscureText: true,
              ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? AppL10n.t.saving : AppL10n.t.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
