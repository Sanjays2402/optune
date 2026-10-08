import AppKit

/// Optune's menu bar glyph: an outlined mouse with a scroll wheel, drawn as a template
/// image so macOS tints it for light/dark menu bars. Original artwork (not an SF Symbol).
enum MenuBarIcon {
    static let image: NSImage = {
        let size = NSSize(width: 14, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let body = NSBezierPath(roundedRect: rect.insetBy(dx: 1.4, dy: 1.0), xRadius: 5.6, yRadius: 5.6)
            body.lineWidth = 1.5
            body.stroke()

            let seam = NSBezierPath()
            seam.move(to: NSPoint(x: rect.midX, y: rect.maxY - 1.4))
            seam.line(to: NSPoint(x: rect.midX, y: rect.maxY - 5.2))
            seam.lineWidth = 1.2
            seam.stroke()

            let wheel = NSBezierPath(
                roundedRect: NSRect(x: rect.midX - 1.1, y: rect.maxY - 8.6, width: 2.2, height: 3.8),
                xRadius: 1.1, yRadius: 1.1)
            wheel.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Optune"
        return image
    }()
}
