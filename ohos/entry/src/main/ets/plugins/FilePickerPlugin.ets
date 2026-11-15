import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import webview from '@ohos.web.webview';

export default class FilePickerPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private webDataChannel: MethodChannel | null = null;
  private context: Context;

  constructor(context: Context) {
    this.context = context;
  }

  getUniqueClassName(): string {
    return 'FilePickerPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'opencode/file');
    this.channel.setMethodCallHandler(this);

    this.webDataChannel = new MethodChannel(
      binding.getBinaryMessenger(),
      'opencode/webdata'
    );
    this.webDataChannel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method === 'clearCookies') {
          try {
            webview.WebCookieManager.clearAllCookiesSync();
          webview.WebStorage.deleteAllData();
            result.success(true);
          } catch (error) {
            result.error('CLEAR_FAILED', (error as Error).message, null);
          }
        } else {
          result.notImplemented();
        }
      }
    });
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel !== null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
    if (this.webDataChannel !== null) {
      this.webDataChannel.setMethodCallHandler(null);
      this.webDataChannel = null;
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'pickPrivateKey') {
      this.pickText().then((text: string) => {
        result.success(text);
      }).catch((error: Error) => {
        result.error('PICK_FAILED', error.message, null);
      });
    } else if (call.method === 'saveFile') {
      const name = call.argument('name') as string;
      const bytes = call.argument('bytes') as Uint8Array;
      this.saveFile(name, bytes).then((path: string) => {
        result.success(path);
      }).catch((error: Error) => {
        result.error('SAVE_FAILED', error.message, null);
      });
    } else {
      result.notImplemented();
    }
  }

  private async saveFile(name: string, bytes: Uint8Array): Promise<string> {
    const documentPicker = new picker.DocumentViewPicker(this.context);
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [name];
    const uris = await documentPicker.save(options);
    if (uris.length === 0) {
      return '';
    }
    const file = fileIo.openSync(
      uris[0],
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC
    );
    try {
      fileIo.writeSync(file.fd, bytes.buffer);
      return uris[0];
    } finally {
      fileIo.closeSync(file);
    }
  }

  private async pickText(): Promise<string> {
    const documentPicker = new picker.DocumentViewPicker(this.context);
    const uris = await documentPicker.select({ maxSelectNumber: 1 });
    if (uris.length === 0) {
      return '';
    }
    const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
    try {
      const stat = fileIo.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      const decoder = util.TextDecoder.create('utf-8');
      return decoder.decodeToString(new Uint8Array(buffer));
    } finally {
      fileIo.closeSync(file);
    }
  }
}
