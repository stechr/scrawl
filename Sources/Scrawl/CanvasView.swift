import AppKit

// A single freehand stroke drawn with the mouse.
struct Stroke {
    var color: NSColor
    var width: CGFloat
    var points: [NSPoint]
    var bornAt: Date? = nil
}

// Programmatic annotation kinds (driven by the control server / an agent).
enum ShapeKind: String {
    case line, arrow, rect, ellipse, circle, freehand, text
}

struct Shape {
    var kind: ShapeKind
    // View coords. line/arrow/rect/ellipse: [from, to]; circle: [center, edge];
    // freehand: many; text: [origin].
    var points: [NSPoint]
    var color: NSColor
    var width: CGFloat
    var text: String? = nil
    var bornAt: Date? = nil
}

final class CanvasView: NSView {
    private(set) var strokes: [Stroke] = []
    private(set) var shapes: [Shape] = []
    private var current: Stroke?

    var strokeColor: NSColor = .systemRed
    var strokeWidth: CGFloat = 4

    var showActiveBorder = false { didSet { needsDisplay = true } }

    // MARK: Fade mode

    var fadeEnabled = false
    var fadeHold: TimeInterval = 2.0
    var fadeOut: TimeInterval = 1.5
    private var fadeTimer: Timer?

    func fadeAlpha(born: Date?) -> CGFloat {
        guard let born = born else { return 1 }
        let age = Date().timeIntervalSince(born)
        if age <= fadeHold { return 1 }
        if age >= fadeHold + fadeOut { return 0 }
        return CGFloat(1 - (age - fadeHold) / fadeOut)
    }

    func startFadeTimer() {
        guard fadeTimer == nil else { return }
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tickFade()
        }
    }

    private func tickFade() {
        let now = Date()
        func expired(_ born: Date?) -> Bool {
            guard let born = born else { return false }
            return now.timeIntervalSince(born) > (fadeHold + fadeOut)
        }
        strokes.removeAll { expired($0.bornAt) }
        shapes.removeAll { expired($0.bornAt) }
        needsDisplay = true
        if !fadeEnabled
            && !strokes.contains(where: { $0.bornAt != nil })
            && !shapes.contains(where: { $0.bornAt != nil }) {
            fadeTimer?.invalidate()
            fadeTimer = nil
        }
    }

    // MARK: Programmatic API (used by the control server)

    func addShape(_ s: Shape) {
        shapes.append(s)
        if s.bornAt != nil { startFadeTimer() }
        needsDisplay = true
    }

    // MARK: Mouse drawing

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        current = Stroke(color: strokeColor, width: strokeWidth, points: [p])
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard current != nil else { return }
        current?.points.append(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if var c = current, c.points.count > 0 {
            if fadeEnabled { c.bornAt = Date(); startFadeTimer() }
            strokes.append(c)
        }
        current = nil
        needsDisplay = true
    }

    func clearAll() {
        strokes.removeAll()
        shapes.removeAll()
        current = nil
        needsDisplay = true
    }

    func undo() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        needsDisplay = true
    }

    // MARK: Rendering

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        dirtyRect.fill()

        for s in strokes { renderStroke(s) }
        if let c = current { renderStroke(c) }
        for sh in shapes { renderShape(sh) }

        if showActiveBorder {
            let frame = NSBezierPath(rect: bounds.insetBy(dx: 2, dy: 2))
            frame.lineWidth = 4
            NSColor.systemRed.withAlphaComponent(0.55).setStroke()
            frame.stroke()
        }
    }

    private func renderStroke(_ s: Stroke) {
        guard let first = s.points.first else { return }
        let alpha = fadeAlpha(born: s.bornAt)
        if alpha <= 0 { return }
        let color = s.color.withAlphaComponent(alpha)
        color.setStroke()
        color.setFill()

        if s.points.count == 1 {
            let r = s.width / 2
            NSBezierPath(ovalIn: NSRect(x: first.x - r, y: first.y - r, width: s.width, height: s.width)).fill()
            return
        }
        let path = NSBezierPath()
        path.lineWidth = s.width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: first)
        for pt in s.points.dropFirst() { path.line(to: pt) }
        path.stroke()
    }

    private func renderShape(_ s: Shape) {
        let alpha = fadeAlpha(born: s.bornAt)
        if alpha <= 0 { return }
        let color = s.color.withAlphaComponent(alpha)
        color.setStroke()
        color.setFill()

        switch s.kind {
        case .line:
            guard s.points.count >= 2 else { return }
            let p = NSBezierPath(); p.lineWidth = s.width; p.lineCapStyle = .round
            p.move(to: s.points[0]); p.line(to: s.points[1]); p.stroke()
        case .arrow:
            guard s.points.count >= 2 else { return }
            drawArrow(from: s.points[0], to: s.points[1], lineWidth: s.width)
        case .rect:
            guard s.points.count >= 2 else { return }
            let p = NSBezierPath(rect: rectFrom(s.points[0], s.points[1])); p.lineWidth = s.width; p.stroke()
        case .ellipse:
            guard s.points.count >= 2 else { return }
            let p = NSBezierPath(ovalIn: rectFrom(s.points[0], s.points[1])); p.lineWidth = s.width; p.stroke()
        case .circle:
            guard s.points.count >= 2 else { return }
            let c = s.points[0]; let r = abs(s.points[1].x - c.x)
            let p = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            p.lineWidth = s.width; p.stroke()
        case .freehand:
            guard let first = s.points.first else { return }
            let p = NSBezierPath(); p.lineWidth = s.width; p.lineCapStyle = .round; p.lineJoinStyle = .round
            p.move(to: first); for pt in s.points.dropFirst() { p.line(to: pt) }; p.stroke()
        case .text:
            guard let origin = s.points.first, let text = s.text else { return }
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: color,
                .font: NSFont.boldSystemFont(ofSize: max(14, s.width * 5))
            ]
            (text as NSString).draw(at: origin, withAttributes: attrs)
        }
    }

    private func rectFrom(_ a: NSPoint, _ b: NSPoint) -> NSRect {
        NSRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    private func drawArrow(from: NSPoint, to: NSPoint, lineWidth: CGFloat) {
        let p = NSBezierPath()
        p.lineWidth = lineWidth; p.lineCapStyle = .round; p.lineJoinStyle = .round
        p.move(to: from); p.line(to: to)
        let angle = atan2(to.y - from.y, to.x - from.x)
        let headLen = max(10, lineWidth * 3)
        let a1 = angle + .pi - .pi / 7
        let a2 = angle + .pi + .pi / 7
        p.move(to: to); p.line(to: NSPoint(x: to.x + cos(a1) * headLen, y: to.y + sin(a1) * headLen))
        p.move(to: to); p.line(to: NSPoint(x: to.x + cos(a2) * headLen, y: to.y + sin(a2) * headLen))
        p.stroke()
    }
}

// A borderless, non-activating panel so drawing on the overlay does not steal
// full app focus from the app underneath (e.g. Keynote/PowerPoint).
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// A small "grip" the user can drag to move the toolbar window.
final class DragHandle: NSView {
    override var intrinsicContentSize: NSSize { NSSize(width: 22, height: 26) }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0.65, alpha: 1).setFill()
        let dot: CGFloat = 1.7
        let sx: CGFloat = 7, sy: CGFloat = 7
        let startX = bounds.midX - sx / 2
        let startY = bounds.midY - sy
        for c in 0..<2 {
            for r in 0..<3 {
                let x = startX + CGFloat(c) * sx
                let y = startY + CGFloat(r) * sy
                NSBezierPath(ovalIn: NSRect(x: x - dot, y: y - dot, width: dot * 2, height: dot * 2)).fill()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

extension NSColor {
    /// Parse "#RRGGBB" (or "RRGGBB").
    convenience init?(hexString: String) {
        var s = hexString
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v >> 16) & 0xff) / 255,
                  green: CGFloat((v >> 8) & 0xff) / 255,
                  blue: CGFloat(v & 0xff) / 255,
                  alpha: 1)
    }
}
