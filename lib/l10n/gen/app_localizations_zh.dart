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
  String get appVersion => 'v1.2.1';

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

  @override
  String get noHostsYet => '还没有主机';

  @override
  String get addFirstHost => '添加第一台主机';

  @override
  String get emptyStateHint => '添加一台 SSH 主机开始使用；macOS 上也可直接使用内置「本机」。';

  @override
  String get addHost => '添加主机';

  @override
  String get manualAdd => '手动添加';

  @override
  String get manualAddSubtitle => '填写地址与私钥';

  @override
  String get scanAdd => '扫码添加';

  @override
  String get scanAddTitle => '扫码添加主机';

  @override
  String get scanAddSubtitle => '从另一台设备的二维码导入';

  @override
  String get emptyStateTitle => '远程 opencode 工作台 · 点击主机开始会话';

  @override
  String get remoteHint => '远程主机：点「添加主机」，填写 SSH 地址、端口、用户名和私钥，保存后点击卡片连接。';

  @override
  String get localFormHint => '本机主机：直连本机 opencode 服务，无需配置连接参数';

  @override
  String get openHost => '打开主机';

  @override
  String get newTab => '新标签页';

  @override
  String get importHost => '导入主机';

  @override
  String get hostTab => '主机';

  @override
  String get editHost => '编辑主机';

  @override
  String get edit => '编辑';

  @override
  String get delete => '删除';

  @override
  String get disconnect => '断开连接';

  @override
  String get exportKey => '导出私钥';

  @override
  String get exportPublicKey => '导出公钥';

  @override
  String get showHostQr => '显示主机二维码';

  @override
  String get localBadge => '本机直连 · 无需 SSH';

  @override
  String get hostDeleted => '该主机已被删除';

  @override
  String favoritesLoadFailed(String error) {
    return '读取收藏失败：$error';
  }

  @override
  String get noFavorites => '还没有收藏文件';

  @override
  String get favoritesHint => '在文件页打开文件后点 ☆ 即可收藏';

  @override
  String get clearFavorites => '清空收藏';

  @override
  String get clearFavoritesTitle => '清空收藏？';

  @override
  String get clearFavoritesBody => '只清除收藏记录，不会删除远端文件。';

  @override
  String get refresh => '刷新';

  @override
  String loadFailed(String error) {
    return '读取失败：$error';
  }

  @override
  String get invalidPort => '端口无效';

  @override
  String readFileFailed(String error) {
    return '读取文件失败：$error';
  }

  @override
  String get publicKeyCopied => '公钥已复制';

  @override
  String get generateNewKey => '生成新密钥';

  @override
  String get keyCommentHint => '公钥注释会显示在 authorized_keys 里，方便以后识别。';

  @override
  String get keyComment => '公钥注释';

  @override
  String get generate => '生成';

  @override
  String get keyGeneratedCopied => '密钥已生成，公钥已复制';

  @override
  String get keyGenerated => '密钥已生成';

  @override
  String generateKeyFailed(String error) {
    return '生成密钥失败：$error';
  }

  @override
  String get checkFormErrors => '请检查表单中的错误';

  @override
  String get unrecognizedKey => '无法识别的私钥格式，请使用 OpenSSH 格式（不支持 .ppk）';

  @override
  String get keyUnrecognized => '私钥格式无法识别';

  @override
  String saveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get nameOptional => '名称（可选）';

  @override
  String get nameHint => '例如：开发机';

  @override
  String get hostAddress => '主机地址';

  @override
  String get hostAddressHint => 'IP 或域名';

  @override
  String get enterHostAddress => '请输入主机地址';

  @override
  String get sshPort => 'SSH 端口';

  @override
  String get username => '用户名';

  @override
  String get enterUsername => '请输入用户名';

  @override
  String get openSshKey => 'OpenSSH 私钥';

  @override
  String get keyKeepHint => '留空表示不修改已保存的私钥';

  @override
  String get pasteKey => '请粘贴 OpenSSH 私钥';

  @override
  String get importFromFile => '从文件导入';

  @override
  String get generateKey => '生成密钥';

  @override
  String get publicKeyClipboard => '公钥（已复制到剪贴板）';

  @override
  String get publicKeyUsage => '把公钥追加到主机 ~/.ssh/authorized_keys';

  @override
  String get copyPublicKey => '复制公钥';

  @override
  String get passphraseOptional => '私钥口令（可选）';

  @override
  String get saving => '保存中…';

  @override
  String get save => '保存';

  @override
  String get hostKeyMissing => '找不到该主机的私钥';

  @override
  String get exportFailed => '导出失败';

  @override
  String get qrStep1 => '在目标设备上点「添加主机 → 扫码添加」，先扫描这张二维码。';

  @override
  String get qrStep2 => '再扫描这张二维码，目标设备会自动完成导入。';

  @override
  String get qrKeyWarning => '二维码包含私钥，关闭本窗口后立即失效。';

  @override
  String get copyContent => '复制内容';

  @override
  String get showStage2 => '已扫描，显示第 2 步';

  @override
  String get done => '完成';

  @override
  String get qrPinHint => '在另一台设备上打开「导入 → 扫码」，并输入 3 位密码。';

  @override
  String scanFailedDetail(String error) {
    return '扫码失败：$error';
  }

  @override
  String scanFailed(String error) {
    return '扫码失败：$error';
  }

  @override
  String get noCameraFallback => '当前平台不支持相机扫码，请在导出端复制内容后使用粘贴导入。';

  @override
  String get clipboardEmpty => '剪贴板为空';

  @override
  String get decrypting => '正在解密并导入…';

  @override
  String hostImported(String name) {
    return '已导入主机「$name」';
  }

  @override
  String get connectAndOpenTitle => '连接并打开？';

  @override
  String connectAndOpenBody(String name) {
    return '需要先连接 $name，然后打开这个文件。';
  }

  @override
  String get connectionNotReady => '连接未就绪';

  @override
  String get noOpenSessions => '没有打开的会话';

  @override
  String get unknownHost => '未知主机';

  @override
  String get retry => '重试';

  @override
  String get connectionFailedTitle => '连接失败';

  @override
  String get detectingOpencode => '检测 opencode…';

  @override
  String get establishingTunnel => '建立隧道…';

  @override
  String get pairing => '配对中…';

  @override
  String openTerminalFailed(String error) {
    return '打开终端失败：$error';
  }

  @override
  String openPdfFailed(String error) {
    return '打开 PDF 失败：$error';
  }

  @override
  String get pdfTooLarge => 'PDF 超过 100MB，暂不支持在 App 内打开';

  @override
  String get disconnectedReconnecting => '连接断开，正在重连…';

  @override
  String get networkReconnecting => '网络中断，正在重连…';

  @override
  String reconnectingWith(String message) {
    return '$message，正在重连…';
  }

  @override
  String closeTabTitle(String name) {
    return '关闭 $name？';
  }

  @override
  String get closeTabBody => '将断开该主机的连接并终止它的终端。其他主机不受影响。';

  @override
  String get close => '关闭';

  @override
  String get quitTitle => '退出方寸台？';

  @override
  String get quitBody => '所有会话连接将被断开。';

  @override
  String get quit => '退出';

  @override
  String connectionFailed(String error) {
    return '连接失败：$error';
  }

  @override
  String get opencodeVersion => 'opencode 版本';

  @override
  String get checkingVersions => '正在获取版本信息…';

  @override
  String get currentVersion => '当前版本';

  @override
  String get latestVersion => '最新版本';

  @override
  String get upgrading => '正在升级…';

  @override
  String get upgradeDone => '升级完成。如果 opencode 服务正在运行，已尝试自动重启服务。';

  @override
  String get operationFailed => '操作失败';

  @override
  String get latestUnknown => '无法获取最新版本（主机无法访问 npm registry）';

  @override
  String get alreadyUpToDate => '已是最新版本';

  @override
  String versionReadFailed(String error) {
    return '无法读取 opencode 版本：$error';
  }

  @override
  String upgradeFailed(String error) {
    return '升级失败：$error';
  }

  @override
  String get opencodeUpgrade => 'opencode 升级';

  @override
  String get continueLabel => '继续';

  @override
  String get quickStartHostsHint =>
      '本机：macOS 上无需 SSH，直接点「本机」卡片即可，会自动发现并启动 opencode 服务。\n远程主机：点「添加主机」，填写 SSH 地址、端口、用户名和私钥，保存后点击卡片连接。';

  @override
  String get preparing => '准备中';

  @override
  String get sshConnecting => '连接 SSH…';

  @override
  String get verifyingKey => '验证密钥…';

  @override
  String get startingOpencodeService => '启动 opencode 服务…';

  @override
  String get connected => '已连接';

  @override
  String get reconnecting => '正在重连…';

  @override
  String get minimize => '最小化';

  @override
  String get closeTerminal => '关闭终端';

  @override
  String get reconnect => '重新连接';

  @override
  String terminalTitle(String name) {
    return '$name · 终端';
  }

  @override
  String get terminal => '终端';

  @override
  String get openingTerminal => '正在打开终端…';

  @override
  String get terminalDisconnected => '终端已断开';

  @override
  String get terminalError => '终端错误';

  @override
  String get connectionClosedBanner => '连接已关闭';

  @override
  String get connectionResumedBanner => '连接已恢复，正在重新打开终端…';

  @override
  String get taskIdle => '未启动';

  @override
  String get taskRunning => '运行中';

  @override
  String get taskStopped => '已停止';

  @override
  String get filesTitle => '文件';

  @override
  String get scanButton => '扫码';

  @override
  String terminalErrorDetail(String error) {
    return '终端错误：$error';
  }

  @override
  String docReloaded(String name) {
    return '「$name」已在服务器上更新，已重新加载';
  }

  @override
  String docConflict(String name) {
    return '「$name」在服务器上已被修改，且存在未保存编辑——保存后请手动刷新';
  }

  @override
  String unsavedChangesFile(String name) {
    return '$name 有未保存的修改。';
  }

  @override
  String unsavedChangesFileW(String name) {
    return '$name 有未保存的修改。';
  }

  @override
  String get pdfTooLarge100 => 'PDF 超过 100MB，暂不支持在 App 内打开';

  @override
  String get selectFromTree => '从目录树选择文件';

  @override
  String get overwriteConfirm => '保存会覆盖远端的最新内容，是否继续？';

  @override
  String get overwrite => '覆盖';

  @override
  String get fileChangedRemotely => '文件已在远端被修改';

  @override
  String get unsavedChanges => '未保存的修改';

  @override
  String get editorNotReady => '编辑器未就绪';

  @override
  String get jumpToPathTitle => '跳转到路径';

  @override
  String get jumpToPath => '跳转到路径…';

  @override
  String get jump => '跳转';

  @override
  String get pathCopied => '路径已复制';

  @override
  String get copyPath => '复制路径';

  @override
  String get copyCommand => '复制命令';

  @override
  String get commandCopied => '命令已复制';

  @override
  String get fileExists => '同名文件已存在';

  @override
  String get nameNoSlash => '名称不能包含 /';

  @override
  String get folderName => '文件夹名';

  @override
  String get fileName => '文件名';

  @override
  String get fileNameNoSlash => '文件名不能包含 /';

  @override
  String get newFile => '新建文件';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get create => '创建';

  @override
  String createFailed(String error) {
    return '创建失败：$error';
  }

  @override
  String fileCreated(String name) {
    return '已创建 $name';
  }

  @override
  String folderCreated(String name) {
    return '已创建 $name/';
  }

  @override
  String deleteFileTitle(String name) {
    return '删除 $name？';
  }

  @override
  String fileDeleted(String name) {
    return '已删除 $name';
  }

  @override
  String deleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get deleteIrreversible => '删除后不可恢复。';

  @override
  String get openTree => '打开目录树';

  @override
  String get collapseTree => '收起目录树';

  @override
  String get expandTree => '展开目录树';

  @override
  String get directoryTree => '目录树';

  @override
  String get favorite => '收藏';

  @override
  String get unfavorite => '取消收藏';

  @override
  String get favorited => '已收藏';

  @override
  String get unfavorited => '已取消收藏';

  @override
  String get clearAll => '清空';

  @override
  String get loading => '加载中…';

  @override
  String get actions => '操作';

  @override
  String get open => '打开';

  @override
  String get download => '下载';

  @override
  String downloadFailed(String error) {
    return '下载失败：$error';
  }

  @override
  String get downloadCancelled => '已取消下载';

  @override
  String copyFailed(String error) {
    return '复制失败：$error';
  }

  @override
  String savedTo(String path) {
    return '已保存到 $path';
  }

  @override
  String unsupportedFile(String extension) {
    return '暂不支持打开 .$extension 文件';
  }

  @override
  String get nonUtf8 => '非 UTF-8 编码，只读打开';

  @override
  String get binaryContent => '检测到二进制内容，无法编辑';

  @override
  String get fileTooLarge2MB => '文件超过 2MB，只读打开';

  @override
  String get fileTooLarge5MB => '文件超过 5MB，暂不支持在 App 内打开';

  @override
  String get notEditable => '该文件不支持编辑';

  @override
  String get thisMachine => '本机';

  @override
  String get quickStart => '快速上手';

  @override
  String get step1Prepare => '① 连接前准备';

  @override
  String get step2Open => '② 打开会话';

  @override
  String get step3Switch => '③ 切换与关闭';

  @override
  String get step4Toolbar => '④ 工具栏';

  @override
  String get tabHint =>
      '顶部标签切换已打开的主机；标签内的 × 关闭该主机会话，只影响这一台。关闭最后一个标签后回到本页，点 + 随时打开新主机。';

  @override
  String get toolbarTerminal => '终端：当前主机的 shell（本机终端暂未支持）。';

  @override
  String serviceStartFailed(String error) {
    return 'opencode 服务启动失败：$error';
  }

  @override
  String serviceStartFailedStatus(String status) {
    return 'opencode 服务启动失败：$status';
  }

  @override
  String localServiceStartFailed(String error) {
    return '本机 opencode 服务启动失败：$error';
  }

  @override
  String get localServiceUnreachable => '本机 opencode 未响应，请启动服务后重试';

  @override
  String get hostOpencodeMissing => '主机未安装 opencode，请先安装后重试';

  @override
  String get localOpencodeMissing => '本机未安装 opencode，请先安装后重试';

  @override
  String get remoteOpencodeUnreachable => '远程 opencode 未响应，请启动服务后重试';

  @override
  String get opencodeCommandFailed => 'opencode 命令失败';

  @override
  String cannotReachHost(String host, String port) {
    return '无法连接主机 $host:$port，请检查网络';
  }

  @override
  String sshConnectFailed(String error) {
    return 'SSH 连接失败：$error';
  }

  @override
  String localPortBusy(String port) {
    return '本地端口 $port 被占用，请更换端口';
  }

  @override
  String pairingFailed(String error) {
    return '配对失败：$error';
  }

  @override
  String pairingFailedHttp(String code) {
    return '配对失败（HTTP $code）';
  }

  @override
  String redeemFailed(String error) {
    return '兑换配对链接失败：$error';
  }

  @override
  String parsePairFailed(String output) {
    return '无法解析配对链接：$output';
  }

  @override
  String parsePairFailedRaw(String output) {
    return '无法解析配对链接：$output';
  }

  @override
  String pairingNoCookie(String code) {
    return '配对链接没有返回会话 cookie（HTTP $code）';
  }

  @override
  String get parseCookieFailed => '无法解析会话 cookie';

  @override
  String createPairFailed(String error) {
    return '生成配对链接失败：$error';
  }

  @override
  String commandFailedCode(String code, String command) {
    return '命令执行失败（退出码 $code）：$command';
  }

  @override
  String commandFailedCodeOnly(String code) {
    return '命令执行失败（退出码 $code）';
  }

  @override
  String get parseVersionFailed => '无法解析 opencode 版本输出';

  @override
  String get opencodeNotFound => '未检测到 opencode。已尝试登录 shell 的 PATH 与常见安装目录。';

  @override
  String get portFieldInvalid => '端口字段无效';

  @override
  String get hostKeyVerificationFailed => '主机指纹校验失败';

  @override
  String get cannotReadDirectory => '无法读取目录';

  @override
  String get permissionDenied => '无权访问：请在「系统设置 → 隐私与安全性 → 文件与文件夹」中允许方寸台';

  @override
  String get toolbarFiles => '文件：浏览当前主机目录，打开 md / pdf / csv / xlsx / docx。';

  @override
  String get toolbarDocuments => '文档：最近打开的文档，继续上次阅读位置。';

  @override
  String filesTitleW(String name) {
    return '$name · 文件';
  }

  @override
  String get installHint =>
      '安装后执行 opencode --version，显示 2.x 即成功；旧版本可用 opencode upgrade --major 升级。Windows 建议在 WSL 中使用。';

  @override
  String get saveFailedSimple => '保存失败';

  @override
  String openFileFailed(String error) {
    return '打开文件失败：$error';
  }

  @override
  String stepOf(String step) {
    return '第 $step 步，共 2 步';
  }

  @override
  String disconnectTitle(String name) {
    return '断开 $name？';
  }

  @override
  String get disconnectShort => '断开';

  @override
  String get qrStage1Waiting => '二维码 1 · 待扫描';

  @override
  String get qrStage2Waiting => '二维码 2 · 待扫描';

  @override
  String get qrFormatUnrecognized => '二维码格式不识别';

  @override
  String get qrContent => '二维码内容';

  @override
  String get qrIncomplete => '二维码内容不完整';

  @override
  String get qrUnreadable => '二维码内容无法识别';

  @override
  String get qrMissingId => '二维码缺少传输标识';

  @override
  String get qrDecryptFailed => '二维码无法解密';

  @override
  String get qrExpired => '二维码已过期，请在源设备重新导出';

  @override
  String get qrNoHost => '二维码中没有主机';

  @override
  String get back => '返回';

  @override
  String get fangchitai => '方寸台';

  @override
  String get zoomIn => '放大';

  @override
  String get zoomInFont => '放大字号';

  @override
  String get discard => '放弃';

  @override
  String get copyPrivateKey => '复制私钥';

  @override
  String get exportKeyPassphrase => '该私钥有 passphrase，导出后仍需原 passphrase。';

  @override
  String get more => '更多';

  @override
  String get publicKeyAuthKeys => '公钥可以添加到主机的 ~/.ssh/authorized_keys。';

  @override
  String get closeWindow => '关闭窗口';

  @override
  String get closeFile => '关闭文件';

  @override
  String get closeFilePageTitle => '关闭文件页？';

  @override
  String get needOtherStage => '还需要扫描另一张二维码';

  @override
  String tunnelFailed(String error) {
    return '建立 SSH 隧道失败：$error';
  }

  @override
  String get closeFilePageBody => '将返回会话页，已保存的文件不会丢失。';

  @override
  String get acceptCode => '接收此码';

  @override
  String get fileNameHint => '例如 notes.md';

  @override
  String get qrMismatch => '两张二维码不匹配，请重新导出';

  @override
  String get keyRejected => '密钥被拒绝，请检查公钥是否已加入主机';

  @override
  String get targetNeedsV2 =>
      '目标主机必须安装 opencode V2。方寸台是它的远程界面，会话、文件、终端能力都来自目标主机上的 opencode。';

  @override
  String get contentCopied => '内容已复制';

  @override
  String toggleEditFailed(String error) {
    return '切换编辑失败：$error';
  }

  @override
  String switchedToTab(String name) {
    return '切换到 $name';
  }

  @override
  String get missingHostFields => '缺少主机字段';

  @override
  String deleteHostTitle(String name) {
    return '删除 $name？';
  }

  @override
  String get upgrade => '升级';

  @override
  String generatePublicKeyFailed(String error) {
    return '生成公钥失败：$error';
  }

  @override
  String get keyIsPassword => '私钥等同于主机密码，请勿泄露。';

  @override
  String get privateKeyCopied => '私钥已复制';

  @override
  String get zoomOut => '缩小';

  @override
  String get zoomOutFont => '缩小字号';

  @override
  String get fileTooLarge50MB => '文件超过 50MB，暂不支持在 App 内打开';

  @override
  String get folderDeleteWarning => '文件夹会连同内部文件一起删除，且不可恢复。';

  @override
  String get parseKeyFailed => '无法解析私钥';

  @override
  String get saved => '已保存';

  @override
  String get disconnected => '已断开连接';

  @override
  String get reading => '阅读';

  @override
  String get paste => '粘贴';

  @override
  String get connectingHost => '正在连接主机…';

  @override
  String get readOnly => '只读';

  @override
  String get hostQrTitle => '主机二维码';

  @override
  String get deleteHostBody => '主机配置和已保存的私钥都会被删除。';

  @override
  String get pasteImportHint => '桌面端可从导出端复制后粘贴到这里';

  @override
  String get pasteImportNoCamera => '桌面端没有相机，可在导出端逐张复制、逐张粘贴。';

  @override
  String get viewerLoadFailedPrefix => '加载失败：';

  @override
  String get viewerLoading => '正在加载…';

  @override
  String get viewerUnsupportedPrefix => '不支持的格式：';

  @override
  String get viewerLoadingPdf => '正在加载 PDF…';

  @override
  String get viewerPdfLoadFailedPrefix => 'PDF 加载失败：';

  @override
  String get connectionLost => '连接中断，请点击重试';

  @override
  String get pageLoadFailed => '页面加载异常，请点击重试';

  @override
  String get pairingLinkExpired => '登录链接已失效，请点击重试';

  @override
  String get exportDiagnostics => '导出诊断日志';

  @override
  String get exportDiagnosticsSubtitle => '保存最近的运行日志用于排查问题';

  @override
  String get exportDiagnosticsEmpty => '暂无诊断记录';
}
