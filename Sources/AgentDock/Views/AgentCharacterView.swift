import SwiftUI

struct AgentCharacterView: View {
    let agent: Agent
    var isCompact: Bool = false

    @State private var isHovered = false
    @State private var showNamePopup = false
    @State private var isBlinking = false

    private var phaseOffset: Double {
        Double(agent.name.hashValue & 0xFF) / 40.0
    }

    // MARK: - Color Palette

    private var skinColor: Color { Color(red: 1.0, green: 0.87, blue: 0.77) }
    private var skinShadow: Color { Color(red: 0.9, green: 0.75, blue: 0.65) }

    private var hairColor: Color {
        switch agent.character {
        case "bear": return Color(red: 0.3, green: 0.22, blue: 0.15)
        case "pig": return Color(red: 0.6, green: 0.3, blue: 0.55)
        case "cat": return Color(red: 0.35, green: 0.35, blue: 0.4)
        default: return Color(red: 0.4, green: 0.3, blue: 0.2)
        }
    }

    private var outfitColor: Color {
        switch agent.character {
        case "bear": return Color(red: 0.25, green: 0.45, blue: 0.75)
        case "pig": return Color(red: 0.80, green: 0.40, blue: 0.65)
        case "cat": return Color(red: 0.35, green: 0.60, blue: 0.50)
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
        ZStack(alignment: .top) {
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

                // Trigger blink randomly
                let _ = triggerBlinkIfNeeded(t: t)

                characterScene(
                    floatY: floatY, tiltX: tiltX, tiltY: tiltY,
                    breathe: breathe, shadowShrink: shadowShrink
                )
            }
            .padding(.top, 70)

            // Always-visible status + tool label
            statusLabel
                .zIndex(5)

            // Name/role popup on hover
            if showNamePopup {
                namePopupView
                    .offset(y: -12)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.8)
                                .combined(with: .opacity)
                                .combined(with: .offset(y: 8)),
                            removal: .opacity
                        )
                    )
                    .zIndex(10)
            }
        }
        .frame(width: 130, height: 240)
        .onHover { hovering in
            isHovered = hovering
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                showNamePopup = hovering
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Blink Timer (via TimelineView)

    @State private var lastBlinkTime: Double = 0
    @State private var nextBlinkInterval: Double = 4.0

    private func triggerBlinkIfNeeded(t: Double) -> Bool {
        if t - lastBlinkTime > nextBlinkInterval && !isBlinking {
            DispatchQueue.main.async {
                lastBlinkTime = t
                nextBlinkInterval = Double.random(in: 2.5...6.0)
                withAnimation(.easeInOut(duration: 0.08)) { isBlinking = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeInOut(duration: 0.08)) { isBlinking = false }
                }
            }
        }
        return true
    }

    // MARK: - Always-Visible Status Label

    private var statusLabel: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(statusColor).frame(width: 6, height: 6)
                Text(statusText)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusColor)
            }

            // Tool HUD: show current tool being used
            if let tool = agent.currentTool {
                HStack(spacing: 3) {
                    Image(systemName: toolIcon(for: tool))
                        .font(.system(size: 7))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(tool)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(statusColor.opacity(0.7))
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(statusColor.opacity(0.3), lineWidth: 0.5))
        )
        .offset(y: 56)
        .animation(.spring(response: 0.3), value: agent.currentTool)
    }

    private func toolIcon(for tool: String) -> String {
        switch tool.lowercased() {
        case "read": return "doc.text"
        case "write": return "square.and.pencil"
        case "edit": return "pencil"
        case "bash": return "terminal"
        case "glob": return "folder.badge.gearshape"
        case "grep": return "magnifyingglass"
        case "webfetch": return "globe"
        case "websearch": return "magnifyingglass.circle"
        default: return "wrench"
        }
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
                        colors: [Color.black.opacity(0.18), Color.black.opacity(0.05), Color.clear],
                        center: .center, startRadius: 0, endRadius: 32
                    )
                )
                .frame(width: 58 * shadowShrink, height: 14 * shadowShrink)
                .offset(y: 52)

            // Pedestal
            pedestal.offset(y: 44)

            // Human avatar with 3D transforms
            humanAvatar
                .offset(y: CGFloat(floatY))
                .scaleEffect(CGFloat(breathe))
                .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        }
        .scaleEffect(isHovered ? 1.0 : 0.85)
        .rotation3DEffect(.degrees(isHovered ? -10 : 0), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.6)
        .rotation3DEffect(.degrees(isHovered ? 3 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
        // Clay double shadow (AFTER scale for resolution)
        .shadow(color: Color.white.opacity(0.35), radius: 4, x: -2, y: -2)  // top highlight
        .shadow(color: outfitColor.opacity(0.25), radius: 8, x: 3, y: 6)    // bottom depth
        .animation(.spring(response: 0.45, dampingFraction: 0.65), value: isHovered)
    }

    // MARK: - Human Avatar Drawing

    private var humanAvatar: some View {
        ZStack {
            VStack(spacing: -6) {
                // HEAD
                ZStack {
                    hairBack

                    // Head circle with skin gradient
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [skinColor, skinShadow],
                                center: .init(x: 0.4, y: 0.3),
                                startRadius: 0, endRadius: 30
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            HStack(spacing: 26) {
                                Circle().fill(Color.pink.opacity(0.18)).frame(width: 10, height: 10)
                                Circle().fill(Color.pink.opacity(0.18)).frame(width: 10, height: 10)
                            }
                            .offset(y: 6)
                        )

                    // Head highlight
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.40), Color.clear],
                                center: .init(x: 0.3, y: 0.2),
                                startRadius: 0, endRadius: 20
                            )
                        )
                        .frame(width: 56, height: 56)

                    hairFront

                    // Eyes with blink + status expression
                    statusEyes

                    // Mouth changes with status
                    statusMouth

                    headAccessory
                }

                // BODY / TORSO
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [outfitLight, outfitColor],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 36)

                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.clear],
                                startPoint: .topLeading, endPoint: .center
                            )
                        )
                        .frame(width: 54, height: 36)

                    outfitDetail
                }
            }

            // Status ring (active states only)
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
        }
    }

    // MARK: - Status-Based Eyes

    private var statusEyes: some View {
        Group {
            switch agent.status {
            case .idle:
                // Normal happy eyes with blink
                HStack(spacing: 14) {
                    eyeNormal
                    eyeNormal
                }
                .offset(y: -2)

            case .working:
                // Focused squint eyes (narrowed)
                HStack(spacing: 14) {
                    eyeSquint
                    eyeSquint
                }
                .offset(y: -2)

            case .thinking:
                // One eye up, looking to the side
                HStack(spacing: 14) {
                    eyeNormal
                    eyeLookUp
                }
                .offset(y: -2)
            }
        }
    }

    // MARK: - Status-Based Mouth

    private var statusMouth: some View {
        Group {
            switch agent.status {
            case .idle:
                // Happy smile
                SmilePath()
                    .stroke(Color(red: 0.7, green: 0.35, blue: 0.30), lineWidth: 2.0)
                    .frame(width: 12, height: 6)
                    .offset(y: 12)

            case .working:
                // Determined small mouth
                Capsule()
                    .fill(Color(red: 0.7, green: 0.35, blue: 0.30))
                    .frame(width: 8, height: 3)
                    .offset(y: 13)

            case .thinking:
                // "Hmm" offset small circle
                Circle()
                    .fill(Color(red: 0.7, green: 0.35, blue: 0.30))
                    .frame(width: 6, height: 6)
                    .offset(x: 3, y: 13)
            }
        }
    }

    // MARK: - Eye Variants

    private var eyeNormal: some View {
        ZStack {
            Ellipse()
                .fill(Color.white)
                .frame(width: 11, height: isBlinking ? 1.5 : 12)
                .overlay(
                    Ellipse().stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                )
            if !isBlinking {
                Circle()
                    .fill(Color(white: 0.12))
                    .frame(width: 6, height: 6)
                    .offset(y: 0.5)
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: 1.2, y: -1.2)
            }
        }
        .animation(.easeInOut(duration: 0.08), value: isBlinking)
    }

    private var eyeSquint: some View {
        // Narrowed focused eye
        ZStack {
            Ellipse()
                .fill(Color.white)
                .frame(width: 11, height: isBlinking ? 1.5 : 7)
                .overlay(
                    Ellipse().stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                )
            if !isBlinking {
                Circle()
                    .fill(Color(white: 0.12))
                    .frame(width: 5.5, height: 5.5)
                    .offset(y: 0)
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 2, height: 2)
                    .offset(x: 1, y: -1)
            }
        }
        .animation(.easeInOut(duration: 0.08), value: isBlinking)
    }

    private var eyeLookUp: some View {
        // Eye looking upward (thinking)
        ZStack {
            Ellipse()
                .fill(Color.white)
                .frame(width: 11, height: isBlinking ? 1.5 : 12)
                .overlay(
                    Ellipse().stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                )
            if !isBlinking {
                Circle()
                    .fill(Color(white: 0.12))
                    .frame(width: 6, height: 6)
                    .offset(x: 1.5, y: -2)  // looking up-right
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: 2.5, y: -3)
            }
        }
        .animation(.easeInOut(duration: 0.08), value: isBlinking)
    }

    // MARK: - Hair Variations

    @ViewBuilder
    private var hairBack: some View {
        switch agent.character {
        case "pig":
            Ellipse()
                .fill(hairColor)
                .frame(width: 60, height: 64)
                .offset(y: -2)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var hairFront: some View {
        switch agent.character {
        case "bear":
            ZStack {
                Capsule().fill(hairColor).frame(width: 56, height: 24).offset(y: -20)
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        Capsule().fill(hairColor)
                            .frame(width: 7, height: 12 + CGFloat(i % 2) * 5)
                    }
                }
                .offset(y: -30)
            }
        case "pig":
            ZStack {
                Capsule().fill(hairColor).frame(width: 58, height: 20).offset(y: -20)
                Capsule().fill(hairColor).frame(width: 32, height: 14)
                    .rotationEffect(.degrees(-15)).offset(x: -12, y: -18)
            }
        case "cat":
            ZStack {
                Capsule().fill(hairColor).frame(width: 58, height: 22).offset(y: -20)
                RoundedRectangle(cornerRadius: 4).fill(hairColor)
                    .frame(width: 16, height: 10)
                    .rotationEffect(.degrees(10)).offset(x: 20, y: -20)
            }
        default:
            Capsule().fill(hairColor).frame(width: 56, height: 22).offset(y: -20)
        }
    }

    // MARK: - Head Accessory

    @ViewBuilder
    private var headAccessory: some View {
        switch agent.character {
        case "cat":
            HStack(spacing: 3) {
                Circle().stroke(Color(white: 0.25), lineWidth: 1.8).frame(width: 16, height: 16)
                Rectangle().fill(Color(white: 0.25)).frame(width: 4, height: 1.8)
                Circle().stroke(Color(white: 0.25), lineWidth: 1.8).frame(width: 16, height: 16)
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
            HStack(spacing: 4) {
                Circle().fill(Color.red.opacity(0.5)).frame(width: 4, height: 4)
                Circle().fill(Color.yellow.opacity(0.5)).frame(width: 4, height: 4)
                Circle().fill(Color.blue.opacity(0.5)).frame(width: 4, height: 4)
            }
            .offset(y: 2)
        case "cat":
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Triangle().fill(Color.white.opacity(0.5))
                        .frame(width: 8, height: 6).rotationEffect(.degrees(15))
                    Triangle().fill(Color.white.opacity(0.5))
                        .frame(width: 8, height: 6).rotationEffect(.degrees(-15)).scaleEffect(x: -1)
                }
                .offset(y: -6)
                Rectangle().fill(Color.red.opacity(0.4)).frame(width: 4, height: 10)
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
        VStack(spacing: 3) {
            Text(agent.name.capitalized)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(agent.role)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Circle().fill(statusColor).frame(width: 7, height: 7)
                Text(statusText)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
        case .idle: return "Completed"
        case .working: return "In Progress"
        case .thinking: return "Analyzing..."
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
