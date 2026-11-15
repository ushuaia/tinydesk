import 'package:flutter/material.dart';

import '../../core/app_language.dart';

import 'package:flutter/services.dart';

import '../../data/host_transfer.dart';
import '../../data/host_repository.dart';
import '../../data/private_key_store.dart';

/// Two-step import: scan (or paste) the key code, then the content code.
/// Both stages must carry the same transfer id before the host is decrypted
/// and imported automatically.
class HostImportDialog extends StatefulWidget {
  const HostImportDialog({
    super.key,
    required this.repository,
    required this.keyStore,
    this.scanner,
  });

  final HostRepository repository;
  final PrivateKeyStore keyStore;

  /// Returns the QR text from the platform scanner, or null when cancelled.
  /// Null (desktop platforms without a camera) hides the scan button and
  /// enables paste import.
  final Future<String?> Function()? scanner;

  @override
  State<HostImportDialog> createState() => _HostImportDialogState();
}

class _HostImportDialogState extends State<HostImportDialog> {
  final _payload = TextEditingController();
  final _receiver = HostTransferReceiver();
  HostTransferStep? _step;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _payload.dispose();
    super.dispose();
  }

  bool get _canScan => widget.scanner != null;

  Future<void> _scan() async {
    setState(() => _error = null);
    try {
      final text = await widget.scanner?.call();
      if (text == null || text.isEmpty) return;
      await _receive(text);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = AppL10n.t.scanFailed(error.toString()));
    }
  }

  Future<void> _paste() async {
    final text = await Clipboard.getData(Clipboard.kTextPlain);
    final value = text?.text?.trim();
    if (value == null || value.isEmpty) {
      setState(() => _error = AppL10n.t.clipboardEmpty);
      return;
    }
    _payload.text = value;
    setState(() => _error = null);
  }

  Future<void> _receive(String text) async {
    try {
      final step = _receiver.receive(text);
      if (!mounted) return;
      setState(() {
        _step = step;
        _error = null;
        _payload.clear();
      });
      if (step == HostTransferStep.ready) {
        await _finish();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      final data = await _receiver.complete();
      final host = await importHostFromTransfer(
        data,
        repository: widget.repository,
        keyStore: widget.keyStore,
      );
      if (!mounted) return;
      Navigator.pop(context, host);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.t.hostImported(host.name))),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _busy = false;
      });
    }
  }

  Widget _progressRow(String label, bool done, bool active) {
    final scheme = Theme.of(context).colorScheme;
    final icon = done
        ? Icon(Icons.check_circle, size: 16, color: scheme.primary)
        : active
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.radio_button_unchecked,
                size: 16, color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: done ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _busy;

    return AlertDialog(
      title: Text(AppL10n.t.scanAddTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _progressRow(AppL10n.t.qrStage1Waiting, _receiver.hasKey,
              _step == HostTransferStep.waitingForPayload),
          _progressRow(AppL10n.t.qrStage2Waiting, _receiver.hasPayload,
              _step == HostTransferStep.waitingForKey),
          const SizedBox(height: 12),
          TextField(
            controller: _payload,
            enabled: !busy,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              labelText: AppL10n.t.qrContent,
              hintText: AppL10n.t.pasteImportHint,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_canScan)
                OutlinedButton.icon(
                  onPressed: busy ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: Text(AppL10n.t.scanButton),
                )
              else
                OutlinedButton.icon(
                  onPressed: busy ? null : _paste,
                  icon: const Icon(Icons.content_paste, size: 18),
                  label: Text(AppL10n.t.paste),
                ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: busy || _payload.text.isEmpty
                    ? null
                    : () => _receive(_payload.text),
                child: Text(AppL10n.t.acceptCode),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_canScan)
            Text(
              AppL10n.t.pasteImportNoCamera,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ],
          if (busy) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(AppL10n.t.decrypting),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(AppL10n.t.cancel),
        ),
      ],
    );
  }
}
