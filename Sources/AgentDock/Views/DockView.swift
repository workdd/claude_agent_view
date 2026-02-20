import SwiftUI

struct DockView: View {
    let viewModel: AgentViewModel
    var onAgentTapped: (Agent) -> Void

    @State private var isCompact = false
    @State private var draggedAgent: Agent?
    @State private var hoveredForDrag: UUID?

    var body: some View {
        VStack(spacing: 0) {
            if isCompact {
                compactDock
            } else {
                fullDock
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isCompact)
        .onAppear { restoreSavedOrder() }
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
                    AgentCharacterView(
                        agent: agent,
                        isCompact: false,
                        lastMessage: agent.messages.last(where: { $0.role == .assistant })?.content
                    )
                    .onTapGesture { onAgentTapped(agent) }
                    .overlay(alignment: .topTrailing) {
                        if hoveredForDrag == agent.id {
                            dragHandle
                        }
                    }
                    .onHover { hovering in
                        hoveredForDrag = hovering ? agent.id : nil
                    }
                    .draggable(agent.name) {
                        dragPreview(for: agent)
                    }
                    .dropDestination(for: String.self) { items, _ in
                        handleDrop(items: items, targetAgent: agent)
                    }
                    .opacity(draggedAgent?.id == agent.id ? 0.4 : 1.0)
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
                    .draggable(agent.name) {
                        dragPreview(for: agent)
                    }
                    .dropDestination(for: String.self) { items, _ in
                        handleDrop(items: items, targetAgent: agent)
                    }
                    .opacity(draggedAgent?.id == agent.id ? 0.4 : 1.0)
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

    // MARK: - Drag & Drop

    private var dragHandle: some View {
        VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 12, height: 2)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 4).fill(.ultraThinMaterial))
        .offset(x: 4, y: 4)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: hoveredForDrag)
    }

    private func dragPreview(for agent: Agent) -> some View {
        Text(agent.name.capitalized)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.ultraThinMaterial))
    }

    private func handleDrop(items: [String], targetAgent: Agent) -> Bool {
        guard let draggedName = items.first,
              let fromIndex = viewModel.agents.firstIndex(where: { $0.name == draggedName }),
              let toIndex = viewModel.agents.firstIndex(where: { $0.id == targetAgent.id }),
              fromIndex != toIndex
        else { return false }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            viewModel.agents.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
        persistAgentOrder()
        return true
    }

    // MARK: - Order Persistence

    private func persistAgentOrder() {
        let names = viewModel.agents.map(\.name)
        UserDefaults.standard.set(names, forKey: "agentOrder")
    }

    private func restoreSavedOrder() {
        guard let savedNames = UserDefaults.standard.stringArray(forKey: "agentOrder"),
              !savedNames.isEmpty
        else { return }

        var reordered: [Agent] = []
        for name in savedNames {
            if let agent = viewModel.agents.first(where: { $0.name == name }) {
                reordered.append(agent)
            }
        }
        // Append any agents not in saved order (newly added)
        for agent in viewModel.agents where !reordered.contains(where: { $0.id == agent.id }) {
            reordered.append(agent)
        }

        if reordered.count == viewModel.agents.count {
            viewModel.agents = reordered
        }
    }

    // MARK: - Backgrounds

    private var dockBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.35, blue: 0.7).opacity(0.08),
                                Color(red: 0.3, green: 0.4, blue: 0.8).opacity(0.05),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .white.opacity(0.05), .white.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
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
