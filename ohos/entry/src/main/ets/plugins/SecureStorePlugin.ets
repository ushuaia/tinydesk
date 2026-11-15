import {
  FlutterPlugin,
  FlutterPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodChannel, {
  MethodCallHandler,
  MethodResult
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';

const ASSET_NOT_FOUND = 24000002;

/**
 * System secure storage for SSH keys and passphrases, backed by the
 * HarmonyOS Asset Store Kit (the platform equivalent of Keychain).
 */
export default class SecureStorePlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;

  getUniqueClassName(): string {
    return 'SecureStorePlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(
      binding.getBinaryMessenger(),
      'opencode/secure'
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
    const key = call.argument('key') as string;
    if (call.method === 'read') {
      this.read(key)
        .then((value: string | null) => {
          result.success(value);
        })
        .catch((error: BusinessError) => {
          result.error('READ_FAILED', error.message, null);
        });
    } else if (call.method === 'write') {
      const value = call.argument('value') as string;
      this.write(key, value)
        .then(() => {
          result.success(true);
        })
        .catch((error: BusinessError) => {
          result.error('WRITE_FAILED', error.message, null);
        });
    } else if (call.method === 'delete') {
      this.delete(key)
        .then(() => {
          result.success(true);
        })
        .catch((error: BusinessError) => {
          result.error('DELETE_FAILED', error.message, null);
        });
    } else {
      result.notImplemented();
    }
  }

  private encode(value: string): Uint8Array {
    return new util.TextEncoder().encodeInto(value);
  }

  private decode(value: Uint8Array): string {
    return util.TextDecoder.create('utf-8').decodeToString(value);
  }

  private async read(key: string): Promise<string | null> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.encode(key));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const found = await asset.query(query);
      if (found.length === 0) {
        return null;
      }
      const secret = found[0].get(asset.Tag.SECRET) as Uint8Array;
      return this.decode(secret);
    } catch (error) {
      if ((error as BusinessError).code === ASSET_NOT_FOUND) {
        return null;
      }
      throw new Error((error as BusinessError).message);
    }
  }

  private async write(key: string, value: string): Promise<void> {
    await this.removeIfPresent(key);
    const attributes: asset.AssetMap = new Map();
    attributes.set(asset.Tag.ALIAS, this.encode(key));
    attributes.set(asset.Tag.SECRET, this.encode(value));
    attributes.set(
      asset.Tag.ACCESSIBILITY,
      asset.Accessibility.DEVICE_FIRST_UNLOCKED
    );
    await asset.add(attributes);
  }

  private async delete(key: string): Promise<void> {
    await this.removeIfPresent(key);
  }

  private async removeIfPresent(key: string): Promise<void> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.encode(key));
    try {
      await asset.remove(query);
    } catch (error) {
      if ((error as BusinessError).code !== ASSET_NOT_FOUND) {
        throw new Error((error as BusinessError).message);
      }
    }
  }
}
