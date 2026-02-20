import SwiftUI

struct AgentCharacterView: View {
    let agent: Agent
    var isCompact: Bool = false

    @State private var isHovered = false
    @State private var showNamePopup = false

    private var phaseOffset: Double {
        Double(agent.name.hashValue & 0xFF) / 40.0
    }

    // MARK: - Color Palette

    private var skinColor: Color { Color(red: 1.0, green: 0.87, blue: 0.77) }
    private var skinShadow: Color { Color(red: 0.9, green: 0.75, blue: 0.65) }

    private var hairColor: Color {
        switch agent.character {
        case "bear": return Color(red: 0.3, green: 0.22, blue: 0.15)   // dark brown
        case "pig": return Color(red: 0.6, green: 0.3, blue: 0.55)     // purple-ish
        case "cat": return Color(red: 0.35, green: 0.35, blue: 0.4)    // dark gray
        default: return Color(red: 0.4, green: 0.3, blue: 0.2)
        }
    }

    private var outfitColor: Color {
        switch agent.character {
        case "bear": return Color(red: 0.25, green: 0.45, blue: 0.75)  // blue hoodie
        case "pig": return Color(red: 0.80, green: 0.40, blue: 0.65)   // pink/creative
        case "cat": return Color(red: 0.35, green: 0.60, blue: 0.50)   // green formal
        default: return .gray
        }
    }

    private var outfitLight: Color {
        switch agent.character {
        case "bear": return Color(red: 0.40, green: 0.60, blue: 0.88)
        case "pig": return Color(red: 0.92, green: 0.55, blue: 0.75)
        case "cat": return Color(red: 0.50, green: 0.75, blue: 0.62)
        default: return .gray.opacity(0.7)
        }
    }

    private var accentColor: Color {
        switch agent.character {
        case "bear": return .blue
        case "pig": return .pink
        case "cat": return .teal
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

    // MARK: - Compact View

    private var compactView: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [outfitLight, outfitColor],
                        center: .init(x: 0.35, y: 0.30),
                        startRadius: 0, endRadius: 18
                    )
                )
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))

            // Mini face
            VStack(spacing: 1) {
                HStack(spacing: 4) {
                    Circle().fill(Color(white: 0.2)).frame(width: 3, height: 3)
                    Circle().fill(Color(white: 0.2)).frame(width: 3, height: 3)
                }
                Capsule()
                    .fill(Color(red: 0.9, green: 0.5, blue: 0.45))
                    .frame(width: 5, height: 2)
            }

            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                .offset(x: 13, y: -13)
        }
        .frame(width: 40, height: 40)
        .scaleEffect(isHovered ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
        .contentShape(Circle())
        .help(agent.name.capitalized)
    }

    // MARK: - Full 3D Animated View

    private var fullView: some View {
        VStack(spacing: 0) {
            // Name popup
            ZStack {
                if showNamePopup {
                    namePopupView
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.8)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(y: 8)),
                                removal: .opacity
                            )
                        )
                }
            }
            .frame(height: 48)

            // 3D Animated Character
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate + phaseOffset
                let speed = statusAnimSpeed
                let intensity = statusAnimIntensity

                let floatY = sin(t * 1.5 * speed) * 5.0 * intensity
                let tiltX = sin(t * 0.8 * speed) * 3.5 * intensity
                let tiltY = cos(t * 0.6 * speed) * 2.5 * intensity
                let breathe = 1.0 + sin(t * 1.2 * speed) * 0.02 * intensity
                let shadowShrink = 1.0 - abs(sin(t * 1.5 * speed)) * 0.12

                characterScene(
                    floatY: floatY, tiltX: tiltX, tiltY: tiltY,
                    breathe: breathe, shadowShrink: shadowShrink
                )
            }
        }
        .frame(width: 110, height: 175)
        .onHover { hovering in
            isHovered = hovering
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                showNamePopup = hovering
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - 3D Character Scene

    private func characterScene(
        floatY: Double, tiltX: Double, tiltY: Double,
        breathe: Double, shadowShrink: Double
    ) -> some View {
        ZStack {
            // Floor shadow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.black.opacity(0.20), Color.clear],
                        center: .center, startRadius: 0, endRadius: 28
                    )
                )
                .frame(width: 52 * shadowShrink, height: 10 * shadowShrink)
                .blur(radius: 3)
                .offset(y: 52)

            // Pedestal
            pedestal.offset(y: 44)

            // Human avatar with 3D transforms
            humanAvatar
                .offset(y: CGFloat(floatY))
                .scaleEffect(CGFloat(breathe))
                .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .shadow(color: outfitColor.opacity(0.3), radius: 10, y: 8)
        }
        .scaleEffect(isHovered ? 1.18 : 1.0)
        .rotation3DEffect(.degrees(isHovered ? -10 : 0), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.6)
        .rotation3DEffect(.degrees(isHovered ? 3 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
        .animation(.spring(response: 0.45, dampingFraction: 0.65), value: isHovered)
    }

    // MARK: - Human Avatar Drawing

    private var humanAvatar: some View {
        ZStack {
            // Ambient glow
            Circle()
                .fill(accentColor.opacity(isHovered ? 0.30 : 0.12))
                .frame(width: 95, height: 95)
                .blur(radius: 18)

            VStack(spacing: -6) {
                // HEAD
                ZStack {
                    // Hair back layer (behind head)
                    hairBack

                    // Head circle with skin gradient (3D lit)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [skinColor, skinShadow],
                                center: .init(x: 0.4, y: 0.3),
                                startRadius: 0, endRadius: 24
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            // Cheek blush
                            HStack(spacing: 22) {
                                Circle().fill(Color.pink.opacity(0.15)).frame(width: 8, height: 8)
                                Circle().fill(Color.pink.opacity(0.15)).frame(width: 8, height: 8)
                            }
                            .offset(y: 5)
                        )

                    // Head highlight (3D light)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.35), Color.clear],
                                center: .init(x: 0.3, y: 0.2),
                                startRadius: 0, endRadius: 16
                            )
                        )
                        .frame(width: 48, height: 48)

                    // Hair front layer
                    hairFront

                    // Eyes
                    HStack(spacing: 12) {
                        eye
                        eye
                    }
                    .offset(y: -2)

                    // Mouth (smile)
                    SmilePath()
                        .stroke(Color(red: 0.7, green: 0.35, blue: 0.30), lineWidth: 1.5)
                        .frame(width: 10, height: 5)
                        .offset(y: 10)

                    // Character-specific accessory on head
                    headAccessory
                }

                // BODY / TORSO
                ZStack {
                    // Torso shape
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [outfitLight, outfitColor],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 30)

                    // Torso highlight
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.clear],
                                startPoint: .topLeading, endPoint: .center
                            )
                        )
                        .frame(width: 46, height: 30)

                    // Outfit detail
                    outfitDetail
                }
            }

            // Status ring
            if agent.status != .idle {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [statusColor.opacity(0.8), statusColor.opacity(0.2), statusColor.opacity(0.8)],
                            center: .center
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 82, height: 82)
                    .offset(y: -2)
            }

            StatusBadgeView(status: agent.status)
                .offset(x: 30, y: -30)
        }
    }

    // MARK: - Eye

    private var eye: some View {
        ZStack {
            Ellipse()
                .fill(Color.white)
                .frame(width: 9, height: 10)
            Circle()
                .fill(Color(white: 0.15))
                .frame(width: 5, height: 5)
                .offset(y: 0.5)
            Circle()
                .fill(Color.white)
                .frame(width: 2, height: 2)
                .offset(x: 1, y: -1)
        }
    }

    // MARK: - Hair Variations

    @ViewBuilder
    private var hairBack: some View {
        switch agent.character {
        case "pig":
            // Long hair back
            Ellipse()
                .fill(hairColor)
                .frame(width: 52, height: 56)
                .offset(y: -2)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var hairFront: some View {
        switch agent.character {
        case "bear":
            // Short spiky hair
            ZStack {
                Capsule()
                    .fill(hairColor)
                    .frame(width: 48, height: 22)
                    .offset(y: -18)
                // Spikes
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        Capsule()
                            .fill(hairColor)
                            .frame(width: 6, height: 10 + CGFloat(i % 2) * 4)
                    }
                }
                .offset(y: -26)
            }
        case "pig":
            // Side-swept bangs
            ZStack {
                Capsule()
                    .fill(hairColor)
                    .frame(width: 50, height: 18)
                    .offset(y: -18)
                Capsule()
                    .fill(hairColor)
                    .frame(width: 28, height: 12)
                    .rotationEffect(.degrees(-15))
                    .offset(x: -10, y: -16)
            }
        case "cat":
            // Neat combed hair
            ZStack {
                Capsule()
                    .fill(hairColor)
                    .frame(width: 50, height: 20)
                    .offset(y: -18)
                RoundedRectangle(cornerRadius: 4)
                    .fill(hairColor)
                    .frame(width: 14, height: 8)
                    .rotationEffect(.degrees(10))
                    .offset(x: 18, y: -18)
            }
        default:
            Capsule()
                .fill(hairColor)
                .frame(width: 48, height: 20)
                .offset(y: -18)
        }
    }

    // MARK: - Head Accessory

    @ViewBuilder
    private var headAccessory: some View {
        switch agent.character {
        case "cat":
            // Round glasses
            HStack(spacing: 4) {
                Circle()
                    .stroke(Color(white: 0.3), lineWidth: 1.5)
                    .frame(width: 13, height: 13)
                Rectangle()
                    .fill(Color(white: 0.3))
                    .frame(width: 4, height: 1.5)
                Circle()
                    .stroke(Color(white: 0.3), lineWidth: 1.5)
                    .frame(width: 13, height: 13)
            }
            .offset(y: -2)
        default:
            EmptyView()
        }
    }

    // MARK: - Outfit Detail

    @ViewBuilder
    private var outfitDetail: some View {
        switch agent.character {
        case "bear":
            // Hoodie strings + code icon
            VStack(spacing: 2) {
                HStack(spacing: 10) {
                    Capsule().fill(Color.white.opacity(0.4)).frame(width: 2, height: 8)
                    Capsule().fill(Color.white.opacity(0.4)).frame(width: 2, height: 8)
                }
                Text("</>")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        case "pig":
            // Creative palette dots
            HStack(spacing: 4) {
                Circle().fill(Color.red.opacity(0.5)).frame(width: 4, height: 4)
                Circle().fill(Color.yellow.opacity(0.5)).frame(width: 4, height: 4)
                Circle().fill(Color.blue.opacity(0.5)).frame(width: 4, height: 4)
            }
            .offset(y: 2)
        case "cat":
            // Formal shirt collar + tie hint
            VStack(spacing: 0) {
                // Collar
                HStack(spacing: 12) {
                    Triangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 8, height: 6)
                        .rotationEffect(.degrees(15))
                    Triangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 8, height: 6)
                        .rotationEffect(.degrees(-15))
                        .scaleEffect(x: -1)
                }
                .offset(y: -6)

                Rectangle()
                    .fill(Color.red.opacity(0.4))
                    .frame(width: 4, height: 10)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Pedestal

    private var pedestal: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [outfitColor.opacity(0.22), outfitColor.opacity(0.06)],
                        center: .center, startRadius: 0, endRadius: 38
                    )
                )
                .frame(width: 70, height: 14)
                .offset(y: -3)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [outfitColor.opacity(0.15), outfitColor.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 76, height: 18)

            Ellipse()
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                .frame(width: 70, height: 14)
                .offset(y: -3)
        }
    }

    // MARK: - Name Popup

    private var namePopupView: some View {
        VStack(spacing: 2) {
            Text(agent.name.capitalized)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(agent.role)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 3) {
                Circle().fill(statusColor).frame(width: 5, height: 5)
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

    private var statusAnimSpeed: Double {
        switch agent.status {
        case .idle: return 1.0
        case .working: return 2.0
        case .thinking: return 0.6
        }
    }

    private var statusAnimIntensity: Double {
        switch agent.status {
        case .idle: return 1.0
        case .working: return 1.8
        case .thinking: return 1.3
        }
    }
}

// MARK: - Custom Shapes

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct SmilePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}
