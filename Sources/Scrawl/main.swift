import AppKit

// Scrawl — a minimal macOS screen-annotation overlay.
// Boots as an .accessory app (no Dock icon); UI lives in a menu-bar item
// and a floating toolbar that controls a transparent full-screen overlay.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
