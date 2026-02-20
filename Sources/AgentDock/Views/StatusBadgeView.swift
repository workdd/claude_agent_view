import SwiftUI

struct StatusBadgeView: View {
    let status: AgentStatus

    @State private var isPulsing = false

    private var color: Color {
        switch status {
        case .idle: return .green
        case .working: return .yellow
        case .thinking: return .orange
        }
    }

    private var label: String {
        switch status {
        case .idle: return ""
        case .working: return ""
        case .thinking: return ""
        }
    }

    var body: some View {
        ZStack {
            // Pulse ring for non-idle states
            if status != .idle {
                Circle()
                    .stroke(color.opacity(0.4), lineWidth: 2)
                    .scaleEffect(isPulsing ? 2.2 : 1.0)
                    .opacity(isPulsing ? 0 : 0.8)
                    .frame(width: 12, height: 12)
            }

            // Main dot
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: color.opacity(0.5), radius: 3)
        }
        .onChange(of: status, initial: true) { _, newValue in
            isPulsing = (newValue != .idle)
        }
        .animation(
            status != .idle
                ? .easeInOut(duration: 1.2).repeatForever(autoreverses: false)
                : .default,
            value: isPulsing
        )
    }
}
