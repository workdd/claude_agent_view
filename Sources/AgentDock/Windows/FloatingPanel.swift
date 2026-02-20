import AppKit

class FloatingPanel: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: style,
            backing: backingStoreType,
            defer: flag
        )
    }

    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 210),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        hasShadow = false

        // Allow dragging by background
        isMovableByWindowBackground = true
    }

    override var canBecomeKey: Bool {
        return true
    }

    // MARK: - Scroll to Reposition

    override func scrollWheel(with event: NSEvent) {
        guard let screen = self.screen ?? NSScreen.main else {
            super.scrollWheel(with: event)
            return
        }

        var origin = self.frame.origin

        // Move panel with scroll (natural scrolling direction)
        origin.y += event.scrollingDeltaY * 2.0
        origin.x -= event.scrollingDeltaX * 2.0

        // Clamp to screen bounds
        let screenFrame = screen.visibleFrame
        let panelSize = self.frame.size
        origin.x = max(screenFrame.minX, min(origin.x, screenFrame.maxX - panelSize.width))
        origin.y = max(screenFrame.minY, min(origin.y, screenFrame.maxY - panelSize.height))

        self.setFrameOrigin(origin)
    }

    // MARK: - Resize for Mode Change

    func resizeForCompact(_ compact: Bool, animated: Bool = true) {
        guard let screen = self.screen ?? NSScreen.main else { return }

        let newWidth: CGFloat = compact ? 260 : 520
        let newHeight: CGFloat = compact ? 56 : 190

        // Keep centered horizontally
        let currentCenter = self.frame.midX
        let newX = currentCenter - newWidth / 2
        let newY = self.frame.origin.y

        // Clamp
        let screenFrame = screen.visibleFrame
        let clampedX = max(screenFrame.minX, min(newX, screenFrame.maxX - newWidth))

        let newFrame = NSRect(
            x: clampedX,
            y: newY,
            width: newWidth,
            height: newHeight
        )

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(newFrame, display: true)
            }
        } else {
            self.setFrame(newFrame, display: true)
        }
    }
}
