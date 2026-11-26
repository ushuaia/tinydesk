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
  private var instanceLockFD: Int32 = -1

  override func awakeFromNib() {
    // A copy started from another bundle (e.g. a build output) does not hold
    // our lock file, but it still shares the saved tunnel ports.
    if let other = otherRunningInstance() {
      NSLog("[TinyDesk] another instance is already running (pid \(other.processIdentifier)); exiting")
      self.orderOut(nil)
      _ = other.activate(options: [.activateAllWindows])
      super.awakeFromNib()
      DispatchQueue.main.async { NSApp.terminate(nil) }
      return
    }

    guard acquireInstanceLock() else {
      NSLog("[TinyDesk] another instance is already running; exiting")
      self.orderOut(nil)
      _ = activateRunningInstance()
      super.awakeFromNib()
      DispatchQueue.main.async { NSApp.terminate(nil) }
      return
    }

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
    self.installTrafficLightActions()

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
      matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .keyDown]
    ) { [weak self] event in
      guard let self = self else { return event }
      // Cmd+` cycles the main page and the open overlays. Handling it here
      // means it still works when a webview or the terminal owns the
      // keyboard focus inside Flutter.
      if event.type == .keyDown, self.isOverlayShortcut(event) {
        self.windowChannel?.invokeMethod("cycleOverlay", arguments: nil)
        return nil
      }
      guard event.window === self else {
        return event
      }
      // Double-clicking the merged title bar (native strip or our 40px
      // headers) zooms the window to the screen, like a native title bar.
      // The traffic-light zone keeps its own behaviour.
      if event.type == .leftMouseDown, event.clickCount == 2 {
        let viewHeight = self.contentView?.bounds.height ?? self.frame.height
        let flutterY = viewHeight - event.locationInWindow.y
        if flutterY >= 0, flutterY <= 40, event.locationInWindow.x > 84 {
          self.zoom(nil)
          return nil
        }
      }
      guard self.blockInput else {
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

  /// One process per logged-in user. Instances share the saved hosts and
  /// their tunnel ports, so a second copy would fight the first over the
  /// same local port (Address already in use).
  private func acquireInstanceLock() -> Bool {
    guard let base = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else {
      return true
    }
    let dir = base.appendingPathComponent("cox.work.tinydesk", isDirectory: true)
    try? FileManager.default.createDirectory(
      at: dir,
      withIntermediateDirectories: true
    )
    let fd = open(dir.appendingPathComponent("app.lock").path, O_CREAT | O_RDWR, 0o644)
    guard fd >= 0 else { return true }
    if flock(fd, LOCK_EX | LOCK_NB) != 0 {
      Darwin.close(fd)
      return false
    }
    instanceLockFD = fd
    return true
  }

  private func otherRunningInstance() -> NSRunningApplication? {
    guard let id = Bundle.main.bundleIdentifier else { return nil }
    return NSRunningApplication.runningApplications(withBundleIdentifier: id)
      .first { $0.processIdentifier != getpid() }
  }

  /// Brings the already-running copy to the front so launching a second
  /// bundle (e.g. a build output) does not look like nothing happened.
  private func activateRunningInstance() -> Bool {
    guard let other = otherRunningInstance() else { return false }
    return other.activate(options: [.activateAllWindows])
  }

  /// Cmd+` (the key left of 1, with or without shift).
  private func isOverlayShortcut(_ event: NSEvent) -> Bool {
    let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    guard mods.contains(.command),
          !mods.contains(.option),
          !mods.contains(.control) else {
      return false
    }
    return event.charactersIgnoringModifiers == "`"
  }

  /// Route the yellow light explicitly. With the title bar merged into the
  /// content view the responder chain no longer reliably delivers
  /// performMiniaturize:, so the standard button gets its own target/action.
  /// The green light keeps the native zoom.
  private func installTrafficLightActions() {
    if let button = standardWindowButton(.miniaturizeButton) {
      button.target = self
      button.action = #selector(trafficLightMiniaturize(_:))
    }
  }

  @objc private func trafficLightMiniaturize(_ sender: Any?) {
    requestFlutterAction("minimizeRequested") { [weak self] in
      self?.performDefaultMiniaturize(nil)
    }
  }

  // Ask Flutter whether it consumes the action (a terminal / file-browser
  // overlay is open); when it answers false, run the native behaviour so the
  // lights keep working on ordinary pages.
  private func requestFlutterAction(_ name: String, fallback: @escaping () -> Void) {
    guard let channel = windowChannel else {
      NSLog("[TinyDesk] \(name): no channel, native fallback")
      fallback()
      return
    }
    channel.invokeMethod(name, arguments: nil) { response in
      let handled = (response as? Bool) ?? false
      NSLog("[TinyDesk] \(name): handled=\(handled)")
      if !handled {
        fallback()
      }
    }
  }

  override func performMiniaturize(_ sender: Any?) {
    requestFlutterAction("minimizeRequested") { [weak self] in
      self?.performDefaultMiniaturize(sender)
    }
  }

  // NB: super.performMiniaturize simulates a click on the standard button;
  // since that button now targets this class, calling super here would
  // recurse. The lower-level action method is safe.
  private func performDefaultMiniaturize(_ sender: Any?) {
    self.miniaturize(nil)
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    if allowClose {
      return true
    }
    windowChannel?.invokeMethod("closeRequested", arguments: nil)
    return false
  }
}
