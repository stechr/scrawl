import AppKit
import ScreenCaptureKit

/// Exports the current canvas to `~/Pictures/Scrawl/scrawl-YYYYMMDD-HHMMSS.png`.
///
/// Two paths:
///  - drawing-only (default): a transparent PNG of just the ink — needs NO
///    permission and always works.
///  - flattened (optional): composites the ink over a ScreenCaptureKit grab of
///    the desktop behind the overlay — needs Screen Recording permission and
///    macOS 14+. Falls back to drawing-only if either is missing.
enum SnapshotExporter {
    enum Result {
        case savedDrawingOnly(URL)
        case savedFlattened(URL)
        case failed(String)
    }

    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures/Scrawl", isDirectory: true)
    }

    static func timestampedURL() -> URL {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        return folder.appendingPathComponent("scrawl-\(fmt.string(from: Date())).png")
    }

    private static func ensureFolder() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// Write the transparent ink PNG. Always available.
    @discardableResult
    static func saveDrawingOnly(_ pngData: Data) -> Result {
        do {
            try ensureFolder()
            let url = timestampedURL()
            try pngData.write(to: url)
            return .savedDrawingOnly(url)
        } catch {
            return .failed("write failed: \(error.localizedDescription)")
        }
    }

    /// Is Screen Recording permission already granted? (no prompt)
    static func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Attempt a flattened export (background + ink). Always calls `completion`
    /// on the main thread; falls back to drawing-only on any failure.
    static func saveFlattened(inkPNG: Data, completion: @escaping (Result) -> Void) {
        func fallback(_ note: String) {
            NSLog("Scrawl: flatten fallback — \(note)")
            let r = saveDrawingOnly(inkPNG)
            DispatchQueue.main.async { completion(r) }
        }

        guard hasScreenRecordingPermission() else {
            // Trigger the system prompt for next time, but don't block this run.
            CGRequestScreenCaptureAccess()
            fallback("no Screen Recording permission (prompted for next time)")
            return
        }

        guard #available(macOS 14.0, *) else {
            fallback("flatten needs macOS 14+ (SCScreenshotManager)")
            return
        }

        guard let ink = NSImage(data: inkPNG) else {
            fallback("could not decode ink PNG")
            return
        }

        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
            guard let content = content, error == nil,
                  let display = content.displays.first else {
                fallback("SCShareableContent error: \(error?.localizedDescription ?? "no display")")
                return
            }
            // Exclude our own app's windows so the toolbar/overlay aren't
            // double-captured; we re-composite the ink ourselves on top.
            let ourPID = ProcessInfo.processInfo.processIdentifier
            let ourApps = content.applications.filter { $0.processID == ourPID }
            let filter = SCContentFilter(display: display,
                                         excludingApplications: ourApps,
                                         exceptingWindows: [])
            let cfg = SCStreamConfiguration()
            cfg.width = display.width
            cfg.height = display.height
            cfg.showsCursor = false

            SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg) { cgImage, err in
                guard let cgImage = cgImage, err == nil else {
                    fallback("captureImage error: \(err?.localizedDescription ?? "nil image")")
                    return
                }
                let size = NSSize(width: CGFloat(display.width), height: CGFloat(display.height))
                let bg = NSImage(cgImage: cgImage, size: size)

                let composed = NSImage(size: size)
                composed.lockFocus()
                bg.draw(in: NSRect(origin: .zero, size: size))
                ink.draw(in: NSRect(origin: .zero, size: size))
                composed.unlockFocus()

                guard let tiff = composed.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    fallback("failed to encode flattened PNG")
                    return
                }
                do {
                    try ensureFolder()
                    let url = timestampedURL()
                    try png.write(to: url)
                    DispatchQueue.main.async { completion(.savedFlattened(url)) }
                } catch {
                    fallback("write failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
