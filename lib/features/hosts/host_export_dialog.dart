import 'package:flutter/material.dart';

import '../../core/app_language.dart';

import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/host.dart';
import '../../data/host_transfer.dart';
import '../../data/private_key_store.dart';

/// Shows the two QR codes of a host transfer one after another. Stage 1 is
/// the random transfer key, stage 2 the encrypted host. Both are generated
/// when the dialog opens and never displayed together.
class HostExportQrDialog extends StatefulWidget {
  const HostExportQrDialog({
    super.key,
    required this.host,
    required this.keyStore,
  });

  final Host host;
  final PrivateKeyStore keyStore;

  @override
  State<HostExportQrDialog> createState() => _HostExportQrDialogState();
}

enum _Phase { loading, keyStage, payloadStage, error }

class _HostExportQrDialogState extends State<HostExportQrDialog> {
  _Phase _phase = _Phase.loading;
  HostTransferStages? _stages;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final key = await widget.keyStore.read(widget.host.id);
      if (!mounted) return;
      if (key == null) {
        setState(() {
          _phase = _Phase.error;
          _error = AppL10n.t.hostKeyMissing;
        });
        return;
      }
      final stages = await createHostTransferStages(
        HostTransferData.fromHost(
          widget.host,
          privateKey: key.$1,
          passphrase: key.$2,
        ),
      );
      if (!mounted) return;
      setState(() {
        _stages = stages;
        _phase = _Phase.keyStage;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = '$error';
      });
    }
  }

  Widget _code(String data) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: QrImageView(data: data, size: 240),
    );
  }

  Widget _stepHeader(int step) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          AppL10n.t.stepOf(step.toString()),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LinearProgressIndicator(
            value: step / 2,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = switch (_phase) {
      _Phase.loading => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      _Phase.error => Text(
          _error ?? AppL10n.t.exportFailed,
          style: TextStyle(color: scheme.error),
        ),
      _Phase.keyStage => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepHeader(1),
            const SizedBox(height: 12),
            Center(child: _code(_stages?.keyStage ?? '')),
            const SizedBox(height: 12),
            Text(
              AppL10n.t.qrStep1,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      _Phase.payloadStage => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepHeader(2),
            const SizedBox(height: 12),
            Center(child: _code(_stages?.payloadStage ?? '')),
            const SizedBox(height: 12),
            Text(
              AppL10n.t.qrStep2,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              AppL10n.t.qrKeyWarning,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.error),
            ),
          ],
        ),
    };

    return AlertDialog(
      title: Text(AppL10n.t.hostQrTitle),
      content: content,
      actions: switch (_phase) {
        _Phase.loading || _Phase.error => [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppL10n.t.close),
            ),
          ],
        _Phase.keyStage => [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppL10n.t.cancel),
            ),
            FilledButton(
              onPressed: () => setState(() => _phase = _Phase.payloadStage),
              child: Text(AppL10n.t.showStage2),
            ),
          ],
        _Phase.payloadStage => [
            TextButton(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: _stages?.payloadStage ?? ''),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppL10n.t.contentCopied)),
                );
              },
              child: Text(AppL10n.t.copyContent),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppL10n.t.done),
            ),
          ],
      },
    );
  }
}
