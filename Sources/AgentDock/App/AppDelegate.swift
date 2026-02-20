import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingPanel: FloatingPanel?
    var chatPanels: [UUID: ChatPanel] = [:]
    var settingsWindow: NSWindow?
    var statusItem: NSStatusItem?
    let viewModel = AgentViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupAppIcon()
        setupMenuBar()
        setupFloatingPanel()
    }

    // MARK: - App Icon (Programmatic)

    private func setupAppIcon() {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size, flipped: false) { rect in
            // Background circle
            let bgPath = NSBezierPath(ovalIn: rect.insetBy(dx: 20, dy: 20))
            NSColor(red: 0.25, green: 0.45, blue: 0.75, alpha: 1.0).setFill()
            bgPath.fill()

            // Inner lighter circle
            let innerRect = rect.insetBy(dx: 60, dy: 60)
            let innerPath = NSBezierPath(ovalIn: innerRect)
            NSColor(red: 0.40, green: 0.62, blue: 0.90, alpha: 1.0).setFill()
            innerPath.fill()

            // Three person silhouettes
            let personSize: CGFloat = 80
            let positions: [(CGFloat, CGFloat, NSColor)] = [
                (156, 220, NSColor(red: 0.95, green: 0.65, blue: 0.75, alpha: 1.0)),  // pink
                (256, 180, NSColor(red: 1.0, green: 0.87, blue: 0.77, alpha: 1.0)),   // center
                (356, 220, NSColor(red: 0.55, green: 0.78, blue: 0.65, alpha: 1.0)),   // green
            ]

            for (x, y, color) in positions {
                // Head
                let headRect = NSRect(x: x - personSize/4, y: y + personSize/3,
                                     width: personSize/2, height: personSize/2)
                let headPath = NSBezierPath(ovalIn: headRect)
                color.setFill()
                headPath.fill()

                // Body
                let bodyRect = NSRect(x: x - personSize/3, y: y - personSize/4,
                                     width: personSize * 0.66, height: personSize/2)
                let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 15, yRadius: 15)
                color.blended(withFraction: 0.3, of: .black)?.setFill()
                bodyPath.fill()
            }

            // "CV" text overlay
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 120, weight: .bold),
                .foregroundColor: NSColor.white.withAlphaComponent(0.9)
            ]
            let text = "CV" as NSString
            let textSize = text.size(withAttributes: attrs)
            let textPoint = NSPoint(
                x: (rect.width - textSize.width) / 2,
                y: rect.height * 0.08
            )
            text.draw(at: textPoint, withAttributes: attrs)

            return true
        }

        NSApp.applicationIconImage = image
    }

    // MARK: - Floating Panel

    private func setupFloatingPanel() {
        let panel = FloatingPanel()
        let dockView = DockView(viewModel: viewModel) { [weak self] agent in
            self?.showChatWindow(for: agent)
        }
        panel.contentView = NSHostingView(rootView: dockView)
        floatingPanel = panel
        positionPanelAtBottom()
        panel.orderFront(nil)

        NotificationCenter.default.addObserver(
            forName: .dockModeChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let compact = notification.userInfo?["compact"] as? Bool {
                self?.floatingPanel?.resizeForCompact(compact)
            }
        }
    }

    func positionPanelAtBottom() {
        guard let panel = floatingPanel,
              let screen = NSScreen.main
        else { return }

        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.minY + 20

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "bubble.left.and.bubble.right.fill",
                accessibilityDescription: "Claude Agent View"
            )
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Dock", action: #selector(showPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Hide Dock", action: #selector(hidePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reset Position", action: #selector(resetPosition), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func showPanel() {
        floatingPanel?.orderFront(nil)
    }

    @objc private func hidePanel() {
        floatingPanel?.orderOut(nil)
    }

    @objc private func resetPosition() {
        positionPanelAtBottom()
        floatingPanel?.resizeForCompact(false, animated: true)
    }

    @objc private func openSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Claude Agent View -- Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false

        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Chat Windows

    func showChatWindow(for agent: Agent) {
        if let existing = chatPanels[agent.id] {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let panel = ChatPanel(title: "\(agent.name) -- \(agent.role)")
        let chatView = ChatView(viewModel: viewModel, agentId: agent.id)
        panel.contentView = NSHostingView(rootView: chatView)

        if let floatingFrame = floatingPanel?.frame {
            let x = floatingFrame.minX
            let y = floatingFrame.maxY + 10
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        chatPanels[agent.id] = panel
        panel.makeKeyAndOrderFront(nil)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.chatPanels.removeValue(forKey: agent.id)
        }
    }
}
