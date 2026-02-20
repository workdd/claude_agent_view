import SwiftUI

struct PerformanceDashboardView: View {
    let viewModel: AgentViewModel

    @State private var metricsMap: [UUID: AgentMetrics] = [:]
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    teamSummary
                    agentCards
                }
                .padding(16)
            }
        }
        .frame(minWidth: 480, minHeight: 420)
        .background(.ultraThinMaterial)
        .onAppear { refreshMetrics() }
        .onReceive(timer) { _ in refreshMetrics() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text("Performance Dashboard")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Team Summary

    private var teamSummary: some View {
        HStack(spacing: 20) {
            summaryCard(
                icon: "message",
                label: "Total Messages",
                value: "\(totalMessages)"
            )
            summaryCard(
                icon: "clock",
                label: "Avg Response",
                value: formatTime(teamAvgResponseTime)
            )
            summaryCard(
                icon: "wrench",
                label: "Tool Calls",
                value: "\(totalToolCalls)"
            )
            summaryCard(
                icon: "dollarsign.circle",
                label: "Est. Tokens",
                value: formatTokens(totalTokens)
            )
        }
    }

    private func summaryCard(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Agent Cards

    private var agentCards: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.agents) { agent in
                agentCard(agent)
            }
        }
    }

    private func agentCard(_ agent: Agent) -> some View {
        let metrics = metricsMap[agent.id] ?? AgentMetrics()

        return HStack(spacing: 14) {
            // Agent color indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(colorForAgent(agent.character))
                .frame(width: 4, height: 60)

            // Agent info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(agent.name.capitalized)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(agent.role)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let lastActive = metrics.lastActiveAt {
                        Text("Last: \(relativeTime(lastActive))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 16) {
                    statItem(icon: "message", label: "Messages", value: "\(metrics.totalMessages)")
                    statItem(icon: "arrow.down.circle", label: "Responses", value: "\(metrics.totalResponses)")
                    statItem(icon: "clock", label: "Avg Time", value: formatTime(metrics.averageResponseTime))
                    statItem(icon: "dollarsign.circle", label: "Tokens", value: formatTokens(metrics.totalTokensEstimate))
                }

                // Tool usage bar
                if !metrics.toolUsageCounts.isEmpty {
                    toolUsageBar(metrics.toolUsageCounts)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    private func statItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .help(label)
    }

    // MARK: - Tool Usage Bar

    private func toolUsageBar(_ counts: [String: Int]) -> some View {
        let total = counts.values.reduce(0, +)
        let sorted = counts.sorted { $0.value > $1.value }

        return HStack(spacing: 2) {
            ForEach(sorted.prefix(6), id: \.key) { tool, count in
                let fraction = total > 0 ? CGFloat(count) / CGFloat(total) : 0
                RoundedRectangle(cornerRadius: 2)
                    .fill(toolColor(tool))
                    .frame(width: max(fraction * 180, 8), height: 6)
                    .help("\(tool): \(count)")
            }
            Spacer()
        }
    }

    private func toolColor(_ tool: String) -> Color {
        switch tool.lowercased() {
        case "read": return .blue
        case "write": return .green
        case "edit": return .orange
        case "bash": return .red
        case "glob": return .purple
        case "grep": return .cyan
        case "webfetch", "websearch": return .indigo
        default: return .gray
        }
    }

    // MARK: - Computed Properties

    private var totalMessages: Int {
        metricsMap.values.reduce(0) { $0 + $1.totalMessages }
    }

    private var totalToolCalls: Int {
        metricsMap.values.reduce(0) { $0 + $1.toolUsageCounts.values.reduce(0, +) }
    }

    private var totalTokens: Int {
        metricsMap.values.reduce(0) { $0 + $1.totalTokensEstimate }
    }

    private var teamAvgResponseTime: TimeInterval {
        let times = metricsMap.values.filter { $0.averageResponseTime > 0 }.map(\.averageResponseTime)
        guard !times.isEmpty else { return 0 }
        return times.reduce(0, +) / Double(times.count)
    }

    // MARK: - Helpers

    private func refreshMetrics() {
        metricsMap = PerformanceService.shared.metricsStore
    }

    private func colorForAgent(_ character: String) -> Color {
        switch character {
        case "bear": return Color(red: 0.25, green: 0.45, blue: 0.75)
        case "pig": return Color(red: 0.80, green: 0.40, blue: 0.65)
        case "cat": return Color(red: 0.35, green: 0.60, blue: 0.50)
        default: return .gray
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "--" }
        if seconds < 1 { return String(format: "%.0fms", seconds * 1000) }
        return String(format: "%.1fs", seconds)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        return "\(Int(interval / 3600))h ago"
    }
}
