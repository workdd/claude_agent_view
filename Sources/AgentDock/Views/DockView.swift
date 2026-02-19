import SwiftUI

struct DockView: View {
    let viewModel: AgentViewModel
    var onAgentTapped: (Agent) -> Void

    @State private var isCompact = false

    var body: some View {
        VStack(spacing: 0) {
            if isCompact {
                compactDock
            } else {
                fullDock
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isCompact)
    }

    // MARK: - Full Dock (3D characters)

    private var fullDock: some View {
        HStack(spacing: 24) {
            ForEach(viewModel.agents) { agent in
                AgentCharacterView(agent: agent, isCompact: false)
                    .onTapGesture { onAgentTapped(agent) }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .background { dockBackground }
        .overlay(alignment: .topTrailing) {
            compactToggleButton(compact: true)
                .padding(8)
        }
    }

    // MARK: - Compact Dock (minimal)

    private var compactDock: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.agents) { agent in
                AgentCharacterView(agent: agent, isCompact: true)
                    .onTapGesture { onAgentTapped(agent) }
            }

            Divider()
                .frame(height: 24)
                .opacity(0.3)

            compactToggleButton(compact: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background { compactBackground }
    }

    // MARK: - Toggle Button

    private func compactToggleButton(compact: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isCompact.toggle()
            }
            // Post notification for panel resize
            NotificationCenter.default.post(
                name: .dockModeChanged,
                object: nil,
                userInfo: ["compact": !isCompact]
            )
        } label: {
            Image(systemName: compact ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(compact ? "Minimize dock" : "Expand dock")
    }

    // MARK: - Backgrounds

    private var dockBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.22), radius: 16, y: 6)
    }

    private var compactBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.20), radius: 10, y: 4)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let dockModeChanged = Notification.Name("dockModeChanged")
}
