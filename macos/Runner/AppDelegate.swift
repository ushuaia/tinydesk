import AVFoundation
import Cocoa
import FlutterMacOS
import Vision
import WebKit

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

/// Native implementations of the two MethodChannels used by the Flutter app.
///
/// macOS does not suspend apps the way mobile OSes do, so the background
/// channel is a no-op that simply reports success.

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

enum TinyDeskChannels {
  /// Opens a native camera window and resolves with the scanned QR text.
  private static let hostScan = HostScanCoordinator()

  static func register(with controller: FlutterViewController) {
    let messenger = controller.engine.binaryMessenger
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
        case "getSessionCookies":
          WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let list: [[String: String]] = cookies.map {
              ["name": $0.name, "value": $0.value, "domain": $0.domain]
            }
            result(list)
          }
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
              result(true)
            }
          } else {
            result(FlutterError(code: "BAD_COOKIE", message: TinyDeskLanguage.text("Could not build the cookie", "无法构造 cookie"), details: nil))
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    FlutterMethodChannel(name: "opencode/background", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "start", "stop", "update":
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    FlutterMethodChannel(name: "opencode/hostscan", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "scan":
          hostScan.scan(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    FlutterMethodChannel(name: "opencode/file", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "pickPrivateKey":
          pickPrivateKey(result: result)
        case "saveFile":
          saveFile(call: call, result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }

  private static func saveFile(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
          let name = args["name"] as? String,
          let typed = args["bytes"] as? FlutterStandardTypedData else {
      result(
        FlutterError(code: "BAD_ARGS", message: TinyDeskLanguage.text("Invalid arguments", "参数错误"), details: nil)
      )
      return
    }
    let panel = NSSavePanel()
    panel.nameFieldStringValue = name
    panel.canCreateDirectories = true
    panel.begin { response in
      guard response == .OK, let url = panel.url else {
        result(nil)
        return
      }
      do {
        try typed.data.write(to: url)
        result(url.path)
      } catch {
        result(
          FlutterError(
            code: "SAVE_FAILED",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }

  private static func pickPrivateKey(result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.message = TinyDeskLanguage.text("Choose a private key file", "选择私钥文件")
    panel.prompt = TinyDeskLanguage.text("Choose", "选择")

    panel.begin { response in
      guard response == .OK, let url = panel.url else {
        result("")
        return
      }
      let accessing = url.startAccessingSecurityScopedResource()
      defer {
        if accessing {
          url.stopAccessingSecurityScopedResource()
        }
      }
      do {
        let text = try String(contentsOf: url, encoding: .utf8)
        result(text)
      } catch {
        result(
          FlutterError(
            code: "PICK_FAILED",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }
}


/// Native QR scanner for macOS: a small window with a live camera preview.
/// Detection runs through AVCaptureMetadataOutput, so no Vision pipeline is
/// needed. Resolves with the scanned text, an empty string when the user
/// closes the window, or a FlutterError when the camera is unavailable.
final class HostScanCoordinator: NSObject,
    NSWindowDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate {
  private var window: NSWindow?
  private let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "hostscan.session")
  private let previewLayer = AVCaptureVideoPreviewLayer()
  private var result: FlutterResult?
  private var frameCounter = 0

  func scan(result: @escaping FlutterResult) {
    if self.result != nil {
      result(FlutterError(code: "BUSY", message: TinyDeskLanguage.text("Scan window is already open", "扫码窗口已打开"), details: nil))
      return
    }
    guard AVCaptureDevice.default(for: .video) != nil else {
      result(FlutterError(code: "NO_CAMERA", message: TinyDeskLanguage.text("No available camera", "未找到可用相机"), details: nil))
      return
    }
    self.result = result
    AVCaptureDevice.requestAccess(for: .video) { granted in
      DispatchQueue.main.async {
        if granted {
          self.showScanner()
        } else {
          self.finish(
            nil,
            error: FlutterError(
              code: "NO_PERMISSION",
              message: TinyDeskLanguage.text("Camera access not granted — allow it in System Settings → Privacy & Security → Camera", "未授权相机访问，请在「系统设置 → 隐私与安全性 → 相机」中允许"),
              details: nil
            )
          )
        }
      }
    }
  }

  /// Shows (and on first use creates) the persistent scanner window.
  ///
  /// The window, its preview layer and the session are deliberately kept
  /// alive for the whole app run: creating and tearing down AppKit windows
  /// inside Flutter callback contexts over-released NSAutorelease objects,
  /// so there is no teardown path at all — only hide/show and start/stop.
  private func showScanner() {
    if window == nil {
      buildScannerWindow()
    }
    window?.makeKeyAndOrderFront(nil)
    sessionQueue.async {
      guard !self.session.isRunning else { return }
      self.configureSessionIfNeeded()
      self.session.startRunning()
    }
  }

  private func buildScannerWindow() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = TinyDeskLanguage.text("Scan QR code", "扫描二维码")
    window.animationBehavior = .none

    let preview = CameraPreviewView(
      frame: NSRect(x: 0, y: 0, width: 420, height: 480),
      previewLayer: previewLayer
    )
    preview.translatesAutoresizingMaskIntoConstraints = false

    let hint = NSTextField(labelWithString: TinyDeskLanguage.text("Point the camera at the host QR code", "将相机对准主机二维码"))
    hint.translatesAutoresizingMaskIntoConstraints = false

    let container = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 520))
    container.addSubview(preview)
    container.addSubview(hint)
    NSLayoutConstraint.activate([
      preview.topAnchor.constraint(equalTo: container.topAnchor),
      preview.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      preview.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      preview.heightAnchor.constraint(equalToConstant: 480),
      hint.topAnchor.constraint(equalTo: preview.bottomAnchor, constant: 10),
      hint.centerXAnchor.constraint(equalTo: container.centerXAnchor),
    ])

    window.contentView = container
    window.delegate = self
    self.window = window
  }

  private func configureSessionIfNeeded() {
    guard !session.isRunning, session.inputs.isEmpty else { return }
    session.beginConfiguration()
    defer { session.commitConfiguration() }
    guard let device = AVCaptureDevice.default(for: .video),
          let input = try? AVCaptureDeviceInput(device: device),
          session.canAddInput(input) else {
      session.commitConfiguration()
      DispatchQueue.main.async {
        self.finish(
          nil,
          error: FlutterError(
            code: "NO_CAMERA",
            message: TinyDeskLanguage.text("Cannot access the camera", "无法访问相机"),
            details: nil
          )
        )
      }
      return
    }
    session.addInput(input)
    let output = AVCaptureVideoDataOutput()
    output.alwaysDiscardsLateVideoFrames = true
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "hostscan.frames", qos: .userInitiated))
    guard session.canAddOutput(output) else {
      session.commitConfiguration()
      DispatchQueue.main.async {
        self.finish(
          nil,
          error: FlutterError(
            code: "NO_OUTPUT",
            message: TinyDeskLanguage.text("Cannot add the video output", "无法添加视频输出"),
            details: nil
          )
        )
      }
      return
    }
    session.addOutput(output)
    if session.canSetSessionPreset(.high) {
      session.sessionPreset = .high
    }
    session.commitConfiguration()

    // startRunning must run after commitConfiguration, or AVFoundation
    // raises NSGenericException and the process aborts.
    previewLayer.session = session
    session.startRunning()
  }

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard result != nil else { return }
    // Decode a few frames per second; Vision QR detection is robust enough
    // for code rotation, so no orientation juggling is needed.
    frameCounter += 1
    if frameCounter % 5 != 0 { return }
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    let request = VNDetectBarcodesRequest()
    request.symbologies = [.QR]
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    try? handler.perform([request])

    for observation in request.results ?? [] {
      if let barcode = observation as? VNBarcodeObservation,
         barcode.symbology == .QR,
         let value = barcode.payloadStringValue,
         !value.isEmpty {
        DispatchQueue.main.async {
          self.finish(value)
        }
        return
      }
    }
  }

  func windowWillClose(_ notification: Notification) {
    DispatchQueue.main.async {
      self.finish(nil)
    }
  }

  private func finish(_ value: String?, error: FlutterError? = nil) {
    guard let callback = result else { return }
    result = nil
    // Never destroy anything here: the window, preview layer and session
    // stay alive for the whole app run (only hidden / stopped), which is
    // what keeps the autorelease pool issues at bay.
    sessionQueue.async {
      self.session.stopRunning()
      DispatchQueue.main.async {
        self.window?.orderOut(nil)
        if let error = error {
          callback(error)
        } else {
          callback(value ?? "")
        }
      }
    }
  }
}

/// Layer-backed view that shows the AVCaptureSession preview.
final class CameraPreviewView: NSView {
  private let previewLayer: AVCaptureVideoPreviewLayer

  init(frame: NSRect, previewLayer: AVCaptureVideoPreviewLayer) {
    self.previewLayer = previewLayer
    super.init(frame: frame)
    wantsLayer = true
  }

  required init?(coder: NSCoder) {
    fatalError("not supported")
  }

  override func makeBackingLayer() -> CALayer {
    previewLayer
  }
}
