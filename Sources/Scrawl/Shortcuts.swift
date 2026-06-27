import AppKit

/// A keyboard shortcut: a base key plus modifier flags. Backed by the JSON
/// config at `~/.scrawl/shortcuts.json` and matched against live key events.
struct Shortcut: Equatable {
    var control: Bool
    var option: Bool
    var command: Bool
    var shift: Bool
    /// Lowercased base key, e.g. "d", "5", or the special "esc".
    var key: String

    init(control: Bool = false, option: Bool = false, command: Bool = false,
         shift: Bool = false, key: String) {
        self.control = control
        self.option = option
        self.command = command
        self.shift = shift
        self.key = key.lowercased()
    }

    /// Parse "ctrl+opt+d" (or "ctrl opt d", "ctrl-opt-d"). Returns nil if the
    /// base key is unknown.
    static func parse(_ raw: String) -> Shortcut? {
        let parts = raw.lowercased()
            .split(whereSeparator: { $0 == "+" || $0 == " " || $0 == "-" })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard let key = parts.last else { return nil }
        var sc = Shortcut(key: key)
        for p in parts.dropLast() {
            switch p {
            case "ctrl", "control", "⌃": sc.control = true
            case "opt", "option", "alt", "⌥": sc.option = true
            case "cmd", "command", "⌘": sc.command = true
            case "shift", "⇧": sc.shift = true
            default: break
            }
        }
        guard Shortcut.keyCode(for: sc.key) != nil else { return nil }
        return sc
    }

    /// Round-trippable string form used in the JSON file / Preferences fields.
    func stringValue() -> String {
        var parts: [String] = []
        if control { parts.append("ctrl") }
        if option { parts.append("opt") }
        if shift { parts.append("shift") }
        if command { parts.append("cmd") }
        parts.append(key)
        return parts.joined(separator: "+")
    }

    /// Compact symbol form for menu titles, e.g. "⌃⌥D".
    func describe() -> String {
        var s = ""
        if control { s += "⌃" }
        if option { s += "⌥" }
        if shift { s += "⇧" }
        if command { s += "⌘" }
        s += (key == "esc" ? "Esc" : key.uppercased())
        return s
    }

    func matches(_ event: NSEvent) -> Bool {
        guard let kc = Shortcut.keyCode(for: key) else { return false }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == kc
            && mods.contains(.control) == control
            && mods.contains(.option) == option
            && mods.contains(.command) == command
            && mods.contains(.shift) == shift
    }

    /// ANSI virtual key codes for the keys we allow binding.
    static func keyCode(for key: String) -> UInt16? {
        if key == "esc" { return 53 }
        let map: [String: UInt16] = [
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
            "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31,
            "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9,
            "w": 13, "x": 7, "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22,
            "7": 26, "8": 28, "9": 25
        ]
        return map[key.lowercased()]
    }
}

/// Loads/saves the shortcut bindings as a flat `action -> "ctrl+opt+x"` JSON
/// object at `~/.scrawl/shortcuts.json`. Minimal on purpose.
enum ShortcutConfig {
    static let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".scrawl", isDirectory: true)
    static let file = dir.appendingPathComponent("shortcuts.json")

    /// Bindable actions and their default bindings, in display order.
    static let defaults: [(action: String, binding: String)] = [
        ("toggleDraw", "ctrl+opt+d"),
        ("undo", "ctrl+opt+z"),
        ("clear", "ctrl+opt+c"),
        ("toggleFade", "ctrl+opt+f"),
        ("toggleToolbar", "ctrl+opt+h"),
        ("toolPen", "ctrl+opt+p"),
        ("toolLine", "ctrl+opt+l"),
        ("toolRect", "ctrl+opt+r"),
        ("toolEllipse", "ctrl+opt+e"),
        ("snapshot", "ctrl+opt+s")
    ]

    static var actionOrder: [String] { defaults.map { $0.action } }

    static let actionLabels: [String: String] = [
        "toggleDraw": "Toggle Draw / Ghost",
        "undo": "Undo",
        "clear": "Clear",
        "toggleFade": "Toggle Fade",
        "toggleToolbar": "Show / Hide Toolbar",
        "toolPen": "Tool: Pen",
        "toolLine": "Tool: Line",
        "toolRect": "Tool: Rectangle",
        "toolEllipse": "Tool: Ellipse",
        "snapshot": "Save Snapshot"
    ]

    /// Returns the merged bindings (defaults overlaid with the user's file).
    /// Writes the defaults file on first run if it is absent.
    static func load() -> [String: Shortcut] {
        var result: [String: Shortcut] = [:]
        for (action, binding) in defaults {
            if let sc = Shortcut.parse(binding) { result[action] = sc }
        }
        if let data = try? Data(contentsOf: file),
           let raw = (try? JSONSerialization.jsonObject(with: data)) as? [String: String] {
            for (action, binding) in raw {
                if let sc = Shortcut.parse(binding) { result[action] = sc }
            }
        } else {
            save(result) // first run — materialize the defaults file
        }
        return result
    }

    static func save(_ shortcuts: [String: Shortcut]) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var raw: [String: String] = [:]
        for (action, sc) in shortcuts { raw[action] = sc.stringValue() }
        if let data = try? JSONSerialization.data(
            withJSONObject: raw, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: file)
        }
    }
}
