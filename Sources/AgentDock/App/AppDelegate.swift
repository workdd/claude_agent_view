import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingPanel: FloatingPanel?
    var chatPanels: [UUID: ChatPanel] = [:]
    var statusItem: NSStatusItem?
    let viewModel = AgentViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupFloatingPanel()
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

        // Listen for dock mode changes
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
                accessibilityDescription: "AgentDock"
            )
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show AgentDock", action: #selector(showPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Hide AgentDock", action: #selector(hidePanel), keyEquivalent: ""))
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
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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

        // Position above the floating panel
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
