import SwiftUI

struct ActivityTimelineView: View {
    @State private var activities: [AgentActivity] = []
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if activities.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(activities.reversed()) { activity in
                            activityRow(activity)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(minWidth: 380, minHeight: 400)
        .background(.ultraThinMaterial)
        .onAppear { refreshActivities() }
        .onReceive(timer) { _ in refreshActivities() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text("Activity Timeline")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
            Text("\(activities.count) events")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Activity Row

    private func activityRow(_ activity: AgentActivity) -> some View {
        HStack(spacing: 10) {
            // Colored dot by agent character
            Circle()
                .fill(colorForAgent(activity.agentName))
                .frame(width: 8, height: 8)

            // Type icon
            Image(systemName: iconForType(activity.type))
                .font(.system(size: 11))
                .foregroundStyle(colorForType(activity.type))
                .frame(width: 18)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(activity.agentName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Text(labelForType(activity.type))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Text(activity.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Relative timestamp
            Text(relativeTime(activity.timestamp))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.02))
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No activity yet")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Start chatting with agents to see activity here.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func refreshActivities() {
        activities = PerformanceService.shared.recentActivities(limit: 50)
    }

    private func iconForType(_ type: AgentActivity.ActivityType) -> String {
        switch type {
        case .messageSent: return "arrow.up.circle"
        case .responseReceived: return "arrow.down.circle"
        case .toolUsed: return "wrench"
        case .statusChanged: return "circle.dotted"
        case .collaborationStarted: return "person.2"
        }
    }

    private func colorForType(_ type: AgentActivity.ActivityType) -> Color {
        switch type {
        case .messageSent: return .blue
        case .responseReceived: return .green
        case .toolUsed: return .orange
        case .statusChanged: return .purple
        case .collaborationStarted: return .pink
        }
    }

    private func labelForType(_ type: AgentActivity.ActivityType) -> String {
        switch type {
        case .messageSent: return "sent message"
        case .responseReceived: return "responded"
        case .toolUsed: return "used tool"
        case .statusChanged: return "status changed"
        case .collaborationStarted: return "collaboration"
        }
    }

    private func colorForAgent(_ name: String) -> Color {
        switch Agent.characterFor(name: name) {
        case "bear": return Color(red: 0.25, green: 0.45, blue: 0.75)
        case "pig": return Color(red: 0.80, green: 0.40, blue: 0.65)
        case "cat": return Color(red: 0.35, green: 0.60, blue: 0.50)
        default: return .gray
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}
