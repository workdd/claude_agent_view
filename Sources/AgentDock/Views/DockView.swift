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

    // MARK: - Full Dock (characters overflow above background)

    private var fullDock: some View {
        ZStack(alignment: .bottom) {
            // Background bar (shorter, sits at bottom)
            dockBackground
                .frame(height: 70)
                .padding(.horizontal, 8)

            // Characters overflow above the background
            HStack(spacing: 24) {
                ForEach(viewModel.agents) { agent in
                    AgentCharacterView(agent: agent, isCompact: false)
                        .onTapGesture { onAgentTapped(agent) }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, -10)

            // Toggle button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    compactToggleButton(compact: true)
                        .padding(.trailing, 18)
                        .padding(.bottom, 6)
                }
            }
        }
        .frame(height: 220)
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
            NotificationCenter.default.post(
                name: .dockModeChanged,
                object: nil,
                userInfo: ["compact": !isCompact]
            )
        } label: {
            Image(systemName: compact ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
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
