import Flutter
import UIKit
import WebKit


/// Language used by native UI, synced from the Flutter app.
enum TinyDeskLanguage {
  static var code: String = "en"

  static func load() {
    code = UserDefaults.standard.string(forKey: "tinydesk.ui_language") ?? "en"
  }

  static func store(_ value: String) {
    code = value == "zh" ? "zh" : "en"
    UserDefaults.standard.set(code, forKey: "tinydesk.ui_language")
  }

  /// Picks between the English and Chinese variant of a native UI string.
  static func text(_ en: String, _ zh: String) -> String {
    code == "zh" ? zh : en
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var pendingPickResult: FlutterResult?
  private var pendingSaveResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TinyDeskChannels") else {
      return
    }
    let messenger = registrar.messenger()
    TinyDeskLanguage.load()

    FlutterMethodChannel(name: "tinydesk/language", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "set":
          if let args = call.arguments as? [String: Any],
             let lang = args["lang"] as? String {
            TinyDeskLanguage.store(lang)
            result(true)
          } else {
            result(FlutterError(code: "BAD_ARGS", message: "bad args", details: nil))
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    FlutterMethodChannel(name: "opencode/webdata", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "clearCookies":
          WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date.distantPast
          ) { result(true) }
        case "setSessionCookie":
          guard let args = call.arguments as? [String: Any],
                let name = args["name"] as? String,
                let value = args["value"] as? String,
                let domain = args["domain"] as? String else {
            result(FlutterError(code: "BAD_ARGS", message: TinyDeskLanguage.text("Invalid arguments", "参数错误"), details: nil))
            return
          }
          if let cookie = HTTPCookie(properties: [
            .name: name,
            .value: value,
            .domain: domain,
            .path: "/",
          ]) {
            WKWebsiteDataStore.default().httpCookieStore.setCookie(cookie) {
              let store = WKWebsiteDataStore.default().httpCookieStore
              store.getAllCookies { cookies in
                let lines = cookies
                  .sorted { $0.name < $1.name }
                  .map { "name=\($0.name) val=\($0.value.prefix(24)) domain=\($0.domain ?? "")" }
                  .joined(separator: "\n")
                try? lines.write(toFile: NSTemporaryDirectory() + "oc_cookies.txt",
                                 atomically: true, encoding: .utf8)
                result(true)
              }
            }
          } else {
            result(FlutterError(code: "BAD_COOKIE", message: TinyDeskLanguage.text("Could not build the cookie", "无法构造 cookie"), details: nil))
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    FlutterMethodChannel(name: "opencode/background", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(nil)
          return
        }
        switch call.method {
        case "start", "update":
          self.beginBackgroundTask()
          result(true)
        case "stop":
          self.endBackgroundTask()
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    FlutterMethodChannel(name: "opencode/file", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "pickPrivateKey":
          self?.pickPrivateKey(result: result)
        case "saveFile":
          self?.saveFile(call: call, result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }

  private func beginBackgroundTask() {
    guard backgroundTask == .invalid else { return }
    backgroundTask = UIApplication.shared.beginBackgroundTask(
      withName: "TinyDeskConnection"
    ) { [weak self] in
      self?.endBackgroundTask()
    }
  }

  private func endBackgroundTask() {
    guard backgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
  }

  private func pickPrivateKey(result: @escaping FlutterResult) {
    guard pendingPickResult == nil else {
      result(FlutterError(code: "PICK_BUSY", message: TinyDeskLanguage.text("Another file picker is already running", "另一个文件选择正在进行"), details: nil))
      return
    }
    guard let root = topViewController() else {
      result(FlutterError(code: "NO_ACTIVITY", message: TinyDeskLanguage.text("Cannot open the file picker", "无法打开文件选择器"), details: nil))
      return
    }
    pendingPickResult = result
    let picker = UIDocumentPickerViewController(
      documentTypes: ["public.data", "public.text"],
      in: .import
    )
    picker.delegate = self
    root.present(picker, animated: true)
  }

  private func saveFile(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard pendingSaveResult == nil else {
      result(
        FlutterError(code: "SAVE_BUSY", message: TinyDeskLanguage.text("Another save is already running", "另一个保存正在进行"), details: nil)
      )
      return
    }
    guard let args = call.arguments as? [String: Any],
          let name = args["name"] as? String,
          let typed = args["bytes"] as? FlutterStandardTypedData else {
      result(
        FlutterError(code: "BAD_ARGS", message: TinyDeskLanguage.text("Invalid arguments", "参数错误"), details: nil)
      )
      return
    }
    guard let root = topViewController() else {
      result(
        FlutterError(code: "NO_ACTIVITY", message: TinyDeskLanguage.text("Cannot open the save panel", "无法打开保存面板"), details: nil)
      )
      return
    }
    let temp = FileManager.default.temporaryDirectory
      .appendingPathComponent(name)
    do {
      try typed.data.write(to: temp)
    } catch {
      result(
        FlutterError(
          code: "SAVE_FAILED",
          message: error.localizedDescription,
          details: nil
        )
      )
      return
    }
    pendingSaveResult = result
    let picker = UIDocumentPickerViewController(
      forExporting: [temp],
      asCopy: true
    )
    picker.delegate = self
    root.present(picker, animated: true)
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}

extension AppDelegate: UIDocumentPickerDelegate {
  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    if let result = pendingSaveResult {
      pendingSaveResult = nil
      result(urls.first?.path)
      return
    }
    guard let result = pendingPickResult else { return }
    pendingPickResult = nil
    guard let url = urls.first else {
      result("")
      return
    }
    do {
      let text = try String(contentsOf: url, encoding: .utf8)
      result(text)
    } catch {
      result(FlutterError(code: "PICK_FAILED", message: error.localizedDescription, details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    if let result = pendingSaveResult {
      pendingSaveResult = nil
      result(nil)
      return
    }
    pendingPickResult?("")
    pendingPickResult = nil
  }
}
