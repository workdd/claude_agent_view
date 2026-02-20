import Foundation

struct AgentMetrics: Codable {
    var totalMessages: Int = 0
    var totalResponses: Int = 0
    var averageResponseTime: TimeInterval = 0
    var toolUsageCounts: [String: Int] = [:]
    var lastActiveAt: Date?
    var totalTokensEstimate: Int = 0

    // Internal tracking for running average
    private var responseTimes: [TimeInterval] = []

    mutating func recordResponseTime(_ time: TimeInterval) {
        responseTimes.append(time)
        averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
    }
}

struct AgentActivity: Identifiable, Codable {
    let id: UUID
    let agentId: UUID
    let agentName: String
    let type: ActivityType
    let detail: String
    let timestamp: Date

    enum ActivityType: String, Codable, CaseIterable {
        case messageSent
        case responseReceived
        case toolUsed
        case statusChanged
        case collaborationStarted
    }

    init(
        id: UUID = UUID(),
        agentId: UUID,
        agentName: String,
        type: ActivityType,
        detail: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.agentId = agentId
        self.agentName = agentName
        self.type = type
        self.detail = detail
        self.timestamp = timestamp
    }
}
