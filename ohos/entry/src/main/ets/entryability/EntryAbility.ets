import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import FilePickerPlugin from '../plugins/FilePickerPlugin';
import BackgroundTaskPlugin from '../plugins/BackgroundTaskPlugin';
import SecureStorePlugin from '../plugins/SecureStorePlugin';
import HostScanPlugin from '../plugins/HostScanPlugin';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    console.info('OCBG: configureFlutterEngine')
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    flutterEngine.getPlugins()?.add(new FilePickerPlugin(this.context))
    console.info('OCBG: adding background plugin')
    flutterEngine.getPlugins()?.add(new BackgroundTaskPlugin(this.context))
    flutterEngine.getPlugins()?.add(new SecureStorePlugin())
    flutterEngine.getPlugins()?.add(new HostScanPlugin())
    console.info('OCBG: background plugin added')
  }
}
