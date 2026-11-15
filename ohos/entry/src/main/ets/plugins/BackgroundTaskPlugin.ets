import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import wantAgent from '@ohos.app.ability.wantAgent';
import common from '@ohos.app.ability.common';

export default class BackgroundTaskPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext;
  private running = false;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  getUniqueClassName(): string {
    return 'BackgroundTaskPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    console.info('OCBG: onAttachedToEngine');
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'opencode/background');
    this.channel.setMethodCallHandler(this);
    backgroundTaskManager.on('continuousTaskCancel', (info: backgroundTaskManager.ContinuousTaskCancelInfo) => {
      console.error('OCBG: cancelled reason=' + info.reason + ' id=' + info.id);
      this.running = false;
    });
    console.info('OCBG: channel ready');
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel !== null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
    backgroundTaskManager.off('continuousTaskCancel');
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'start') {
      console.info('OCBG: start requested');
      this.start().then(() => {
        console.info('OCBG: started');
        result.success(true);
      }).catch((error: Error) => {
        console.error('OCBG: start failed ' + error.message);
        result.error('BG_FAILED', error.message, null);
      });
    } else if (call.method === 'stop') {
      this.stop().then(() => {
        console.info('OCBG: stopped');
        result.success(true);
      }).catch((error: Error) => {
        console.error('OCBG: stop failed ' + error.message);
        result.error('BG_FAILED', error.message, null);
      });
    } else if (call.method === 'update') {
      this.update().then(() => {
        console.info('OCBG: updated');
        result.success(true);
      }).catch((error: Error) => {
        console.error('OCBG: update failed ' + error.message);
        result.error('BG_FAILED', error.message, null);
      });
    } else {
      result.notImplemented();
    }
  }

  private async start(): Promise<void> {
    if (this.running) {
      try {
        await this.stop();
      } catch (error) {
        console.error('OCBG: stop before restart failed ' + (error as Error).message);
        this.running = false;
      }
    }
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: this.context.applicationInfo.name,
          abilityName: 'EntryAbility'
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent = await wantAgent.getWantAgent(info);
      const notification = await backgroundTaskManager.startBackgroundRunning(
        this.context,
        ['dataTransfer'],
        agent
      );
      this.running = true;
      console.info('OCBG: started ' + JSON.stringify(notification));
    } catch (error) {
      this.running = false;
      console.error('OCBG: start failed ' + (error as Error).message);
      throw new Error((error as Error).message);
    }
  }

  private async stop(): Promise<void> {
    if (!this.running) return;
    try {
      await backgroundTaskManager.stopBackgroundRunning(this.context);
    } finally {
      this.running = false;
    }
  }

  private async update(): Promise<void> {
    if (!this.running) {
      await this.start();
      return;
    }
    try {
      await backgroundTaskManager.updateBackgroundRunning(this.context, ['dataTransfer']);
    } catch (error) {
      console.error('OCBG: update failed, restarting ' + (error as Error).message);
      this.running = false;
      await this.start();
    }
  }
}
