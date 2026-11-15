import 'package:flutter/material.dart';
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
          _error = '找不到该主机的私钥';
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
          '第 $step 步，共 2 步',
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
          _error ?? '导出失败',
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
              '在目标设备上点「添加主机 → 扫码添加」，先扫描这张二维码。',
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
              '再扫描这张二维码，目标设备会自动完成导入。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '二维码包含私钥，关闭本窗口后立即失效。',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.error),
            ),
          ],
        ),
    };

    return AlertDialog(
      title: const Text('主机二维码'),
      content: content,
      actions: switch (_phase) {
        _Phase.loading || _Phase.error => [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        _Phase.keyStage => [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => setState(() => _phase = _Phase.payloadStage),
              child: const Text('已扫描，显示第 2 步'),
            ),
          ],
        _Phase.payloadStage => [
            TextButton(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: _stages?.payloadStage ?? ''),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('内容已复制')),
                );
              },
              child: const Text('复制内容'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
      },
    );
  }
}
