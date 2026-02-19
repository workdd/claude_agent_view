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

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.4), lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.8 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
            )
            .onChange(of: status, initial: true) { _, newValue in
                isPulsing = (newValue == .thinking)
            }
            .animation(
                status == .thinking
                    ? .easeInOut(duration: 1.0).repeatForever(autoreverses: false)
                    : .default,
                value: isPulsing
            )
    }
}
