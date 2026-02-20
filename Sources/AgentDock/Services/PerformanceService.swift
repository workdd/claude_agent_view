import Foundation

class PerformanceService {
    static let shared = PerformanceService()

    private(set) var metricsStore: [UUID: AgentMetrics] = [:]
    private(set) var activities: [AgentActivity] = []

    private let metricsURL: URL
    private var saveTask: Task<Void, Never>?

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".agentdock")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        metricsURL = dir.appendingPathComponent("metrics.json")
        loadFromDisk()
    }

    // MARK: - Recording

    func recordMessageSent(agentId: UUID, agentName: String) {
        var metrics = metricsStore[agentId] ?? AgentMetrics()
        metrics.totalMessages += 1
        metrics.lastActiveAt = Date()
        metricsStore[agentId] = metrics

        addActivity(agentId: agentId, agentName: agentName, type: .messageSent, detail: "Message sent")
    }

    func recordResponseReceived(agentId: UUID, agentName: String, responseTime: TimeInterval, tokenEstimate: Int) {
        var metrics = metricsStore[agentId] ?? AgentMetrics()
        metrics.totalResponses += 1
        metrics.totalTokensEstimate += tokenEstimate
        metrics.recordResponseTime(responseTime)
        metrics.lastActiveAt = Date()
        metricsStore[agentId] = metrics

        let detail = String(format: "Response in %.1fs (~%d tokens)", responseTime, tokenEstimate)
        addActivity(agentId: agentId, agentName: agentName, type: .responseReceived, detail: detail)
    }

    func recordToolUse(agentId: UUID, agentName: String, tool: String) {
        var metrics = metricsStore[agentId] ?? AgentMetrics()
        metrics.toolUsageCounts[tool, default: 0] += 1
        metrics.lastActiveAt = Date()
        metricsStore[agentId] = metrics

        addActivity(agentId: agentId, agentName: agentName, type: .toolUsed, detail: tool)
    }

    func getMetrics(for agentId: UUID) -> AgentMetrics {
        metricsStore[agentId] ?? AgentMetrics()
    }

    // MARK: - Activity Log

    func addActivity(agentId: UUID, agentName: String, type: AgentActivity.ActivityType, detail: String) {
        let activity = AgentActivity(agentId: agentId, agentName: agentName, type: type, detail: detail)
        activities.append(activity)

        // Cap at 500 entries to prevent unbounded growth
        if activities.count > 500 {
            activities = Array(activities.suffix(400))
        }

        scheduleSave()
    }

    func recentActivities(limit: Int = 50) -> [AgentActivity] {
        Array(activities.suffix(limit))
    }

    // MARK: - Persistence (debounced)

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.saveToDisk()
        }
    }

    private struct PersistedData: Codable {
        let metrics: [String: AgentMetrics] // UUID string keys
        let activities: [AgentActivity]
    }

    private func saveToDisk() {
        let stringKeyedMetrics = Dictionary(
            uniqueKeysWithValues: metricsStore.map { ($0.key.uuidString, $0.value) }
        )
        let data = PersistedData(metrics: stringKeyedMetrics, activities: activities)
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: metricsURL, options: .atomic)
        } catch {
            print("[PerformanceService] Save failed: \(error)")
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: metricsURL) else { return }
        do {
            let persisted = try JSONDecoder().decode(PersistedData.self, from: data)
            metricsStore = Dictionary(
                uniqueKeysWithValues: persisted.metrics.compactMap { key, value in
                    guard let uuid = UUID(uuidString: key) else { return nil }
                    return (uuid, value)
                }
            )
            activities = persisted.activities
        } catch {
            print("[PerformanceService] Load failed: \(error)")
        }
    }
}
