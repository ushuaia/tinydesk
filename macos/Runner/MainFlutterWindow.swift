import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  private var windowChannel: FlutterMethodChannel?
  private var inputChannel: FlutterMethodChannel?
  private var eventMonitor: Any?
  private var blockInput = false
  private var contentLeft: CGFloat = 0
  private var contentTop: CGFloat = 0
  private var allowClose = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setContentSize(NSSize(width: 1440, height: 900))
    self.center()

    // Merge the system title bar into our own: transparent title bar with
    // full-size content lets the Flutter surface draw its own header, with
    // the traffic lights overlaying it, instead of stacking two title bars.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = false

    RegisterGeneratedPlugins(registry: flutterViewController)
    TinyDeskChannels.register(with: flutterViewController)

    // The red traffic-light button is intercepted so Flutter can decide
    // whether to close the current page or confirm quitting the app.
    let channel = FlutterMethodChannel(
      name: "opencode/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "confirmClose":
        self?.allowClose = true
        self?.close()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    windowChannel = channel
    self.delegate = self

    // Native input interceptor for overlays above WKWebView: while the tree
    // panel covers the content, clicks and scroll-wheel inside the content
    // rectangle are swallowed and forwarded to Dart (which closes the panel).
    let input = FlutterMethodChannel(
      name: "opencode/input",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    input.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "setBlocking":
        if let args = call.arguments as? [String: Any] {
          self.blockInput = args["blocking"] as? Bool ?? false
          self.contentLeft = (args["left"] as? NSNumber)?.doubleValue ?? 0
          self.contentTop = (args["top"] as? NSNumber)?.doubleValue ?? 0
        } else {
          self.blockInput = false
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    inputChannel = input
    eventMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
    ) { [weak self] event in
      guard let self = self, self.blockInput, event.window === self else {
        return event
      }
      let point = event.locationInWindow
      // AppKit y grows upward; Flutter y grows downward.
      let viewHeight = self.contentView?.bounds.height ?? self.frame.height
      let flutterY = viewHeight - point.y
      if point.x > self.contentLeft && flutterY > self.contentTop {
        self.inputChannel?.invokeMethod("intercepted", arguments: nil)
        return nil
      }
      return event
    }

    super.awakeFromNib()
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    if allowClose {
      return true
    }
    windowChannel?.invokeMethod("closeRequested", arguments: nil)
    return false
  }
}
