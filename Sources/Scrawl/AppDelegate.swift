import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlay: OverlayPanel!
    private var canvas: CanvasView!
    private var toolbar: NSPanel!
    private var statusItem: NSStatusItem!
    private var controlServer: ControlServer?

    private var toggleButton: NSButton!
    private var fadeButton: NSButton!
    private var collapseButton: NSButton!
    private var toolbarStack: NSStackView!
    private var dragHandle: DragHandle!
    private var collapsibleViews: [NSView] = []
    private var isCollapsed = false
    private var swatchButtons: [NSButton] = []

    // Draw mode = overlay captures the mouse. Ghost mode = clicks pass through.
    private var isDrawing = false {
        didSet { applyMode() }
    }

    // Control+Option key combos (ANSI virtual key codes).
    private let kToggle: UInt16 = 2 // D
    private let kClear: UInt16 = 8  // C
    private let kUndo: UInt16 = 6   // Z

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupOverlay()
        setupToolbar()
        setupStatusItem()
        setupHotkeys()
        applyMode()
        startControlServer()
    }

    // MARK: - Overlay

    private func setupOverlay() {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        overlay = OverlayPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = false
        overlay.level = .screenSaver // floats above normal windows + presentations
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        overlay.ignoresMouseEvents = true // start in ghost mode

        canvas = CanvasView(frame: NSRect(origin: .zero, size: screen.frame.size))
        canvas.autoresizingMask = [.width, .height]
        overlay.contentView = canvas
        overlay.orderFrontRegardless()
    }

    // MARK: - Toolbar

    private func setupToolbar() {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        toolbarStack = stack

        collapseButton = NSButton(title: "‹", target: self, action: #selector(toggleCollapse))
        collapseButton.bezelStyle = .rounded
        collapseButton.toolTip = "Collapse / expand the toolbar"
        stack.addArrangedSubview(collapseButton)

        toggleButton = NSButton(title: "✏️ Draw", target: self, action: #selector(toggleMode))
        toggleButton.bezelStyle = .rounded
        stack.addArrangedSubview(toggleButton)

        stack.addArrangedSubview(separator())

        let colors: [(String, NSColor)] = [
            ("red", .systemRed), ("blue", .systemBlue), ("green", .systemGreen),
            ("yellow", .systemYellow), ("black", .black), ("white", .white)
        ]
        for (i, item) in colors.enumerated() {
            let b = swatch(color: item.1, tag: i)
            swatchButtons.append(b)
            stack.addArrangedSubview(b)
        }
        highlightSwatch(0)

        stack.addArrangedSubview(separator())

        for (title, width) in [("S", CGFloat(2)), ("M", CGFloat(4)), ("L", CGFloat(8))] {
            let b = NSButton(title: title, target: self, action: #selector(setWidth(_:)))
            b.bezelStyle = .rounded
            b.tag = Int(width)
            stack.addArrangedSubview(b)
        }

        stack.addArrangedSubview(separator())

        fadeButton = NSButton(title: "⏱ Fade: Off", target: self, action: #selector(toggleFade))
        fadeButton.bezelStyle = .rounded
        fadeButton.toolTip = "When on, each stroke fades out and disappears after a few seconds."
        stack.addArrangedSubview(fadeButton)

        stack.addArrangedSubview(separator())

        let undo = NSButton(title: "Undo", target: self, action: #selector(undoStroke))
        undo.bezelStyle = .rounded
        stack.addArrangedSubview(undo)

        let clear = NSButton(title: "Clear", target: self, action: #selector(clearCanvas))
        clear.bezelStyle = .rounded
        stack.addArrangedSubview(clear)

        let quit = NSButton(title: "Quit", target: self, action: #selector(quit))
        quit.bezelStyle = .rounded
        stack.addArrangedSubview(quit)

        // Everything that hides when collapsed = all items except the collapse
        // chevron, the Draw/Ghost toggle, and the (later-added) drag handle.
        collapsibleViews = stack.arrangedSubviews.filter { $0 !== collapseButton && $0 !== toggleButton }

        // Drag handle on the right — always visible; drag it to move the bar.
        dragHandle = DragHandle()
        stack.addArrangedSubview(dragHandle)

        let content = NSView()
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.92).cgColor
        content.layer?.cornerRadius = 12
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])

        let size = stack.fittingSize
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let originX = screen.frame.midX - size.width / 2
        let originY = screen.frame.minY + 60

        toolbar = NSPanel(
            contentRect: NSRect(x: originX, y: originY, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        toolbar.isOpaque = false
        toolbar.backgroundColor = .clear
        toolbar.hasShadow = true
        toolbar.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        toolbar.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        toolbar.isMovableByWindowBackground = true
        toolbar.contentView = content
        toolbar.orderFrontRegardless()
    }

    private func separator() -> NSView {
        let v = NSBox()
        v.boxType = .separator
        return v
    }

    private func swatch(color: NSColor, tag: Int) -> NSButton {
        let b = NSButton(title: "", target: self, action: #selector(pickColor(_:)))
        b.tag = tag
        b.isBordered = false
        b.wantsLayer = true
        b.layer?.backgroundColor = color.cgColor
        b.layer?.cornerRadius = 6
        b.layer?.borderColor = NSColor.white.cgColor
        b.layer?.borderWidth = 0
        b.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            b.widthAnchor.constraint(equalToConstant: 22),
            b.heightAnchor.constraint(equalToConstant: 22)
        ])
        return b
    }

    private func highlightSwatch(_ tag: Int) {
        for b in swatchButtons {
            b.layer?.borderWidth = (b.tag == tag) ? 3 : 0
        }
    }

    // MARK: - Menu-bar item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "✏️"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Drawing (⌃⌥D)", action: #selector(toggleMode), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Undo (⌃⌥Z)", action: #selector(undoStroke), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Clear (⌃⌥C)", action: #selector(clearCanvas), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Toggle Fade Mode", action: #selector(toggleFade), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Show/Hide Toolbar", action: #selector(toggleToolbar), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Scrawl", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // MARK: - Hotkeys (Control+Option + key)

    private func setupHotkeys() {
        // Local monitor: when our app receives the event. Global monitor: when
        // another app is focused (requires Accessibility permission).
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleHotkey(event) == true { return nil }
            return event
        }
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleHotkey(event)
        }
    }

    @discardableResult
    private func handleHotkey(_ event: NSEvent) -> Bool {
        // Escape always leaves drawing mode — no modifier required.
        if event.keyCode == 53 { // Esc
            if isDrawing { isDrawing = false; return true }
            return false
        }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard mods == [.control, .option] else { return false }
        switch event.keyCode {
        case kToggle: toggleMode(); return true
        case kClear: clearCanvas(); return true
        case kUndo: undoStroke(); return true
        default: return false
        }
    }

    // MARK: - Mode + actions

    private func applyMode() {
        overlay.ignoresMouseEvents = !isDrawing
        canvas.showActiveBorder = isDrawing
        toggleButton?.title = isDrawing ? "👻 Ghost (Esc)" : "✏️ Draw"
        statusItem?.button?.title = isDrawing ? "✏️ ●" : "✏️"
        if isDrawing {
            overlay.makeKeyAndOrderFront(nil)
        }
        // Always keep the toolbar above the overlay so you can click to exit.
        toolbar?.orderFrontRegardless()
    }

    @objc private func toggleMode() { isDrawing.toggle() }

    @objc private func pickColor(_ sender: NSButton) {
        let map: [NSColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .black, .white]
        if sender.tag < map.count {
            canvas.strokeColor = map[sender.tag]
            highlightSwatch(sender.tag)
        }
        if !isDrawing { isDrawing = true } // picking a colour implies you want to draw
    }

    @objc private func setWidth(_ sender: NSButton) {
        canvas.strokeWidth = CGFloat(sender.tag)
    }

    @objc private func toggleCollapse() {
        isCollapsed.toggle()
        for v in collapsibleViews { v.isHidden = isCollapsed }
        collapseButton.title = isCollapsed ? "›" : "‹"
        resizeToolbarToFit()
    }

    private func resizeToolbarToFit() {
        toolbarStack.layoutSubtreeIfNeeded()
        let size = toolbarStack.fittingSize
        var frame = toolbar.frame
        let top = frame.maxY          // keep the top-left corner anchored
        frame.size = size
        frame.origin.y = top - size.height
        toolbar.setFrame(frame, display: true)
    }

    @objc private func toggleFade() {        canvas.fadeEnabled.toggle()
        if canvas.fadeEnabled { canvas.startFadeTimer() }
        fadeButton.title = canvas.fadeEnabled ? "⏱ Fade: On" : "⏱ Fade: Off"
    }

    @objc private func undoStroke() { canvas.undo() }
    @objc private func clearCanvas() { canvas.clearAll() }
    @objc private func toggleToolbar() { toolbar.isVisible ? toolbar.orderOut(nil) : toolbar.orderFrontRegardless() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }

    // MARK: - Control server (loopback HTTP, agent-drivable)

    /// Screen center of a view in TOP-LEFT global points (CGEvent convention).
    private func screenCenterTopLeft(_ v: NSView) -> [String: Double]? {
        guard let win = v.window else { return nil }
        let inWin = v.convert(v.bounds, to: nil)
        let onScreen = win.convertToScreen(inWin)
        let screenH = (NSScreen.main ?? NSScreen.screens.first!).frame.height
        return ["cx": Double(onScreen.midX), "cy": Double(screenH - onScreen.midY)]
    }

    /// Report toolbar button centers so an agent can click them via CGEvent.
    private func toolbarLayout() -> [String: Any] {
        var buttons: [String: Any] = [:]
        func reg(_ name: String, _ v: NSView?) {
            if let v = v, let c = screenCenterTopLeft(v) { buttons[name] = c }
        }
        reg("collapse", collapseButton)
        reg("draw", toggleButton)
        reg("fade", fadeButton)
        reg("drag", dragHandle)
        let colors = ["red", "blue", "green", "yellow", "black", "white"]
        for (i, b) in swatchButtons.enumerated() where i < colors.count { reg("swatch_\(colors[i])", b) }
        let scr = NSScreen.main ?? NSScreen.screens.first!
        return ["ok": true, "buttons": buttons, "screen": ["w": Double(scr.frame.width), "h": Double(scr.frame.height)]]
    }

    private func startControlServer() {
        guard !CommandLine.arguments.contains("--no-serve") else { return }
        controlServer = ControlServer(port: 7777) { [weak self] body in
            self?.handleControl(body) ?? ["ok": false, "error": "not ready"]
        }
        controlServer?.start()
    }

    /// Runs on the main thread (ControlServer dispatches here). Accepts either a
    /// single command object or {"commands":[ ... ]} (batch — the efficient path).
    private func handleControl(_ body: [String: Any]) -> [String: Any] {
        if (body["op"] as? String) == "layout" { return toolbarLayout() }
        if let cmds = body["commands"] as? [[String: Any]] {
            var applied = 0
            for c in cmds where applyCommand(c) { applied += 1 }
            return ["ok": true, "applied": applied, "total": cmds.count]
        }
        return ["ok": applyCommand(body)]
    }

    /// op: line|arrow|rect|ellipse|circle|freehand|text|clear|mode.
    /// Coords are normalized 0..1 with a TOP-LEFT origin (web/Playwright style).
    @discardableResult
    private func applyCommand(_ c: [String: Any]) -> Bool {
        guard let op = c["op"] as? String else { return false }
        switch op {
        case "clear":
            canvas.clearAll(); return true
        case "mode":
            if let m = c["mode"] as? String { isDrawing = (m == "draw") }
            return true
        default:
            guard let kind = ShapeKind(rawValue: op) else { return false }
            let b = canvas.bounds
            func pt(_ a: Any?) -> NSPoint? {
                guard let arr = a as? [Any], arr.count == 2,
                      let nx = (arr[0] as? NSNumber)?.doubleValue,
                      let ny = (arr[1] as? NSNumber)?.doubleValue else { return nil }
                // normalized top-left → view coords (AppKit bottom-left origin)
                return NSPoint(x: CGFloat(nx) * b.width, y: (1 - CGFloat(ny)) * b.height)
            }
            let color = parseColor(c["color"])
            let width = CGFloat((c["width"] as? NSNumber)?.doubleValue ?? 4)
            let born: Date? = ((c["fade"] as? Bool) ?? false) ? Date() : nil

            var points: [NSPoint] = []
            switch kind {
            case .line, .arrow, .rect, .ellipse:
                guard let f = pt(c["from"]), let t = pt(c["to"]) else { return false }
                points = [f, t]
            case .circle:
                guard let at = pt(c["at"]) else { return false }
                let r = CGFloat((c["r"] as? NSNumber)?.doubleValue ?? 0.04) * b.height
                points = [at, NSPoint(x: at.x + r, y: at.y)]
            case .freehand:
                guard let raw = c["points"] as? [Any] else { return false }
                points = raw.compactMap { pt($0) }
                if points.isEmpty { return false }
            case .text:
                guard let at = pt(c["at"]) else { return false }
                points = [at]
            }

            canvas.addShape(Shape(kind: kind, points: points, color: color,
                                  width: width, text: c["text"] as? String, bornAt: born))
            return true
        }
    }

    private func parseColor(_ v: Any?) -> NSColor {
        guard let s = (v as? String)?.lowercased() else { return .systemRed }
        switch s {
        case "red": return .systemRed
        case "blue": return .systemBlue
        case "green": return .systemGreen
        case "yellow": return .systemYellow
        case "orange": return .systemOrange
        case "black": return .black
        case "white": return .white
        default: return NSColor(hexString: s) ?? .systemRed
        }
    }
}
