import {
  FlutterPlugin,
  FlutterPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodChannel, {
  MethodCallHandler,
  MethodResult
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * Opens the system QR scanner and returns the scanned text. The system
 * screen hosts the camera, so no extra permission is declared by the app.
 */
export default class HostScanPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;

  getUniqueClassName(): string {
    return 'HostScanPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(
      binding.getBinaryMessenger(),
      'opencode/hostscan'
    );
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel !== null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'scan') {
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: true,
      };
      scanBarcode.startScanForResult(getContext(), options)
        .then((scanResult: scanBarcode.ScanResult) => {
          result.success(scanResult.originalValue ?? '');
        })
        .catch((error: BusinessError) => {
          if (error.code === 1000201 || error.code === 1000202) {
            // User closed the scanner.
            result.success('');
          } else {
            result.error('SCAN_FAILED', error.message, null);
          }
        });
    } else {
      result.notImplemented();
    }
  }
}
