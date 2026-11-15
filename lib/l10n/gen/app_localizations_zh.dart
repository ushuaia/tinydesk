// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get settings => '设置';

  @override
  String get appearanceSection => '外观';

  @override
  String get darkMode => '深色模式';

  @override
  String get fontScale => '字体缩放';

  @override
  String get connectionSection => '连接';

  @override
  String get keepAlive => '后台保活';

  @override
  String get keepAliveSubtitle => '切到后台时尽量维持 SSH 隧道';

  @override
  String get autoBlurKeyboard => '进入会话时自动收起键盘';

  @override
  String get autoBlurKeyboardSubtitle => '避免打开会话时自动弹出输入法';

  @override
  String get backgroundTask => '长时任务';

  @override
  String get dataSection => '数据';

  @override
  String get clearData => '清除数据';

  @override
  String get clearDataSubtitle => '删除所有主机和密钥';

  @override
  String get clearDataConfirmTitle => '清除数据';

  @override
  String get clearDataConfirmBody => '将删除所有主机配置和密钥，此操作不可撤销。';

  @override
  String get cancel => '取消';

  @override
  String get clear => '清除';

  @override
  String get dataCleared => '数据已清除';

  @override
  String clearFailed(String error) {
    return '清除失败：$error';
  }

  @override
  String get aboutSection => '关于';

  @override
  String get appName => '方寸台 TinyDesk';

  @override
  String get appVersion => 'v1.1.1';

  @override
  String get language => '语言';

  @override
  String get followSystem => '跟随系统';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get languageUpdated => '语言已更新';
}
