import SwiftUI

struct AgentCharacterView: View {
    let agent: Agent
    var isCompact: Bool = false

    @State private var isHovered = false
    @State private var bounceOffset: CGFloat = 0
    @State private var breatheScale: CGFloat = 1.0
    @State private var thinkingRotation: Double = 0
    @State private var showNamePopup = false

    private var emoji: String {
        switch agent.character {
        case "bear": return "\u{1F43B}"   // bear
        case "pig": return "\u{1F437}"    // pig
        case "cat": return "\u{1F431}"    // cat
        default: return "\u{1F916}"       // robot
        }
    }

    // MARK: - Color Palette per Character

    private var primaryColor: Color {
        switch agent.character {
        case "bear": return Color(hue: 0.07, saturation: 0.55, brightness: 0.82)
        case "pig": return Color(hue: 0.92, saturation: 0.40, brightness: 0.92)
        case "cat": return Color(hue: 0.58, saturation: 0.35, brightness: 0.88)
        default: return Color.gray
        }
    }

    private var secondaryColor: Color {
        switch agent.character {
        case "bear": return Color(hue: 0.05, saturation: 0.65, brightness: 0.60)
        case "pig": return Color(hue: 0.85, saturation: 0.50, brightness: 0.70)
        case "cat": return Color(hue: 0.62, saturation: 0.50, brightness: 0.65)
        default: return Color.gray.opacity(0.7)
        }
    }

    private var accentGlow: Color {
        switch agent.character {
        case "bear": return .orange
        case "pig": return .pink
        case "cat": return .cyan
        default: return .gray
        }
    }

    // MARK: - Body

    var body: some View {
        if isCompact {
            compactView
        } else {
            fullView
        }
    }

    // MARK: - Compact View (small orb only)

    private var compactView: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [primaryColor, secondaryColor],
                        center: .init(x: 0.35, y: 0.30),
                        startRadius: 0, endRadius: 18
                    )
                )
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.5), Color.clear],
                                center: .init(x: 0.30, y: 0.22),
                                startRadius: 0, endRadius: 12
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

            Text(emoji).font(.system(size: 18))

            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle().stroke(Color.white, lineWidth: 1.5)
                )
                .offset(x: 13, y: -13)
        }
        .frame(width: 40, height: 40)
        .scaleEffect(isHovered ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
        .contentShape(Circle())
        .help(agent.name.capitalized)
    }

    // MARK: - Full 3D View

    private var fullView: some View {
        VStack(spacing: 0) {
            // Hover name popup (above character)
            ZStack {
                if showNamePopup {
                    namePopupView
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.85)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(y: 8)),
                                removal: .opacity
                            )
                        )
                }
            }
            .frame(height: 50)

            // 3D Glass Orb Character
            ZStack {
                // Outer ambient glow
                Circle()
                    .fill(accentGlow.opacity(isHovered ? 0.25 : 0.1))
                    .frame(width: 90, height: 90)
                    .blur(radius: 16)

                // Floor shadow (3D depth)
                Ellipse()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 54, height: 10)
                    .offset(y: 40)
                    .blur(radius: 5)

                // Main glass sphere
                ZStack {
                    // Base sphere with radial gradient
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [primaryColor, secondaryColor],
                                center: .init(x: 0.35, y: 0.30),
                                startRadius: 0, endRadius: 38
                            )
                        )
                        .frame(width: 72, height: 72)

                    // Glass highlight (upper-left light source)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.55),
                                    Color.white.opacity(0.15),
                                    Color.clear
                                ],
                                center: .init(x: 0.28, y: 0.22),
                                startRadius: 0, endRadius: 24
                            )
                        )
                        .frame(width: 72, height: 72)

                    // Bottom rim reflection
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.white.opacity(0.08)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 72, height: 72)

                    // Glass edge stroke
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.clear,
                                    secondaryColor.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 71, height: 71)

                    // Character emoji with 3D shadow
                    Text(emoji)
                        .font(.system(size: 36))
                        .shadow(color: secondaryColor.opacity(0.6), radius: 3, y: 3)
                }
                .offset(y: bounceOffset)
                .scaleEffect(breatheScale)
                .rotationEffect(.degrees(agent.status == .thinking ? thinkingRotation : 0))
                .shadow(color: secondaryColor.opacity(0.35), radius: 10, y: 6)

                // Status ring (animated for working/thinking)
                if agent.status != .idle {
                    Circle()
                        .stroke(statusColor.opacity(0.7), lineWidth: 2.5)
                        .frame(width: 80, height: 80)
                        .scaleEffect(breatheScale)
                }

                // Status badge
                StatusBadgeView(status: agent.status)
                    .offset(x: 28, y: -28)
            }
            .frame(width: 90, height: 90)
        }
        .frame(width: 100, height: 150)
        .scaleEffect(isHovered ? 1.10 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showNamePopup = hovering
            }
        }
        .contentShape(Rectangle())
        .onChange(of: agent.status, initial: true) { _, newStatus in
            updateAnimations(for: newStatus)
        }
        .onAppear {
            startIdleAnimation()
        }
    }

    // MARK: - Hover Name Popup

    private var namePopupView: some View {
        VStack(spacing: 2) {
            Text(agent.name.capitalized)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(agent.role)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 3) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 5, height: 5)
                Text(statusText)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
    }

    // MARK: - Status Helpers

    private var statusColor: Color {
        switch agent.status {
        case .idle: return .green
        case .working: return .yellow
        case .thinking: return .orange
        }
    }

    private var statusText: String {
        switch agent.status {
        case .idle: return "Ready"
        case .working: return "Working..."
        case .thinking: return "Thinking..."
        }
    }

    // MARK: - Animations

    private func updateAnimations(for status: AgentStatus) {
        withAnimation(.easeInOut(duration: 0.3)) {
            bounceOffset = 0
            breatheScale = 1.0
            thinkingRotation = 0
        }

        switch status {
        case .idle: startIdleAnimation()
        case .working: startWorkingAnimation()
        case .thinking: startThinkingAnimation()
        }
    }

    private func startIdleAnimation() {
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            breatheScale = 1.04
        }
    }

    private func startWorkingAnimation() {
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            bounceOffset = -6
        }
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            breatheScale = 1.07
        }
    }

    private func startThinkingAnimation() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            thinkingRotation = 8
        }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            breatheScale = 1.03
        }
    }
}
