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

    // Secrets live in a keychain item whose ACL allows any application, so
    // reads never prompt. flutter_secure_storage items are bound to the
    // creating signature, and macOS asks twice (item + its protected key)
    // whenever the app is re-signed.
    let secure = FlutterMethodChannel(
      name: "opencode/secure",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    secure.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "read":
        result(self.secureRead(args["key"] as? String ?? ""))
      case "write":
        let status = self.secureWrite(
          args["key"] as? String ?? "",
          args["value"] as? String ?? ""
        )
        if status == errSecSuccess {
          result(nil)
        } else {
          result(FlutterError(code: "secure_write", message: "OSStatus \(status)", details: nil))
        }
      case "delete":
        let status = self.secureDelete(args["key"] as? String ?? "")
        result(status == errSecSuccess || status == errSecItemNotFound ? nil :
          FlutterError(code: "secure_delete", message: "OSStatus \(status)", details: nil))
      default:
        result(FlutterMethodNotImplemented)
      }
    }

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
      // Cmd+J cycles the main page and the open overlays. Handling it here
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

  /// Cmd+J toggles between the main page and the open overlays.
  // MARK: - Secret storage

  private static let secureService = "cox.work.tinydesk"

  private func secureQuery(_ key: String) -> [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: MainFlutterWindow.secureService,
      kSecAttrAccount: key,
    ]
  }

  private func secureRead(_ key: String) -> String? {
    var query = secureQuery(key)
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  /// Access object that trusts only this application.
  ///
  /// The item is created by the app (stable Apple Development signature),
  /// so reading it back never prompts, while any other process still needs
  /// the user's authorisation.
  private func secureAccessForSelf() -> SecAccess? {
    var access: SecAccess?
    guard SecAccessCreate(
      MainFlutterWindow.secureService as CFString,
      [] as CFArray,
      &access
    ) == errSecSuccess, let accessRef = access else { return nil }

    var trustedApp: SecTrustedApplication?
    guard SecTrustedApplicationCreateFromPath(nil, &trustedApp) == errSecSuccess,
          let app = trustedApp else { return accessRef }
    let trusted = [app] as CFArray

    var aclList: CFArray?
    guard SecAccessCopyACLList(accessRef, &aclList) == errSecSuccess,
          let list = aclList else { return accessRef }
    for index in 0..<CFArrayGetCount(list) {
      let acl = unsafeBitCast(CFArrayGetValueAtIndex(list, index), to: SecACL.self)
      let authorizations = SecACLCopyAuthorizations(acl)
      SecACLSetContents(acl, trusted, MainFlutterWindow.secureService as CFString, [])
      SecACLUpdateAuthorizations(acl, authorizations)
    }
    return accessRef
  }

  private func secureWrite(_ key: String, _ value: String) -> OSStatus {
    SecItemDelete(secureQuery(key) as CFDictionary)
    var attributes = secureQuery(key)
    attributes[kSecValueData] = Data(value.utf8)
    if let access = secureAccessForSelf() {
      attributes[kSecAttrAccess] = access
    }
    return SecItemAdd(attributes as CFDictionary, nil)
  }

  private func secureDelete(_ key: String) -> OSStatus {
    SecItemDelete(secureQuery(key) as CFDictionary)
  }

  private func isOverlayShortcut(_ event: NSEvent) -> Bool {
    let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    guard mods.contains(.command),
          !mods.contains(.option),
          !mods.contains(.control) else {
      return false
    }
    return event.charactersIgnoringModifiers?.lowercased() == "j"
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
