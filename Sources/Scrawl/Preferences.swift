import AppKit

/// A small window to view/edit shortcut bindings (action -> "ctrl+opt+x").
/// On Save it persists to `~/.scrawl/shortcuts.json` and calls `onSave` so the
/// app can re-register its hotkeys. Deliberately minimal — text-field entry,
/// no recorder.
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private var fields: [String: NSTextField] = [:]
    private var shortcuts: [String: Shortcut]
    private let onSave: ([String: Shortcut]) -> Void

    init(shortcuts: [String: Shortcut], onSave: @escaping ([String: Shortcut]) -> Void) {
        self.shortcuts = shortcuts
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Scrawl Preferences"
        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func buildUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Keyboard Shortcuts")
        title.font = .boldSystemFont(ofSize: 14)
        stack.addArrangedSubview(title)

        let hint = NSTextField(labelWithString: "Format: ctrl+opt+d   (modifiers: ctrl, opt, cmd, shift)")
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .secondaryLabelColor
        stack.addArrangedSubview(hint)

        for action in ShortcutConfig.actionOrder {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 8

            let label = NSTextField(labelWithString: ShortcutConfig.actionLabels[action] ?? action)
            label.alignment = .right
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 160).isActive = true

            let field = NSTextField(string: shortcuts[action]?.stringValue() ?? "")
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 180).isActive = true
            fields[action] = field

            row.addArrangedSubview(label)
            row.addArrangedSubview(field)
            stack.addArrangedSubview(row)
        }

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        cancel.bezelStyle = .rounded
        let save = NSButton(title: "Save", target: self, action: #selector(saveClicked))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        buttons.addArrangedSubview(cancel)
        buttons.addArrangedSubview(save)
        stack.addArrangedSubview(buttons)

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
        window?.contentView = content
        window?.setContentSize(stack.fittingSize)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func cancelClicked() { window?.close() }

    @objc private func saveClicked() {
        var updated = shortcuts
        for (action, field) in fields {
            let text = field.stringValue.trimmingCharacters(in: .whitespaces)
            if text.isEmpty { continue }
            if let sc = Shortcut.parse(text) {
                updated[action] = sc
                field.textColor = .labelColor
            } else {
                // Invalid binding — flag it and keep the window open.
                field.textColor = .systemRed
                NSSound.beep()
                return
            }
        }
        shortcuts = updated
        ShortcutConfig.save(updated)
        onSave(updated)
        window?.close()
    }
}
