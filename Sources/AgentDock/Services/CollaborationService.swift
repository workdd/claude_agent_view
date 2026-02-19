import Foundation

struct CollaborationTask: Identifiable {
    let id: UUID
    let originalMessage: String
    let targetAgentIds: [UUID]
    var responses: [UUID: String]  // agentId -> response
    var status: CollaborationStatus
    let createdAt: Date

    init(message: String, targetAgentIds: [UUID]) {
        self.id = UUID()
        self.originalMessage = message
        self.targetAgentIds = targetAgentIds
        self.responses = [:]
        self.status = .pending
        self.createdAt = Date()
    }

    var isComplete: Bool {
        responses.count == targetAgentIds.count
    }
}

enum CollaborationStatus {
    case pending
    case inProgress
    case complete
}

class CollaborationService {

    // MARK: - Parse @mentions

    /// Extract @mentions from a message.
    /// Supports: @Backend, @Frontend, @Researcher, @all
    static func parseMentions(from message: String, agents: [Agent]) -> (cleanMessage: String, mentionedIds: [UUID]) {
        var mentionedIds: [UUID] = []
        var cleanMessage = message

        // Check for @all
        if message.lowercased().contains("@all") {
            cleanMessage = cleanMessage.replacingOccurrences(
                of: "@all",
                with: "",
                options: .caseInsensitive
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            return (cleanMessage, agents.map(\.id))
        }

        // Check for individual @mentions
        for agent in agents {
            let mention = "@\(agent.name)"
            if message.localizedCaseInsensitiveContains(mention) {
                mentionedIds.append(agent.id)
                cleanMessage = cleanMessage.replacingOccurrences(
                    of: mention,
                    with: "",
                    options: .caseInsensitive
                )
            }
        }

        cleanMessage = cleanMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleanMessage, mentionedIds)
    }

    // MARK: - Build Collaboration Context

    /// Create a system prompt addendum that tells the agent about the collaboration.
    static func collaborationContext(
        currentAgent: Agent,
        allAgents: [Agent],
        mentionedIds: [UUID]
    ) -> String {
        let teammates = allAgents.filter { mentionedIds.contains($0.id) && $0.id != currentAgent.id }
        guard !teammates.isEmpty else { return "" }

        let teamInfo = teammates.map { "\($0.name) (\($0.role))" }.joined(separator: ", ")
        return """

        [Collaboration Mode]
        This task is assigned to multiple agents: you and \(teamInfo).
        Focus on your specialty (\(currentAgent.role)). \
        Be concise — your response will be combined with others.
        """
    }

    // MARK: - Format Combined Response

    /// Merge responses from multiple agents into a single formatted output.
    static func formatCombinedResponse(task: CollaborationTask, agents: [Agent]) -> String {
        var sections: [String] = []
        for agentId in task.targetAgentIds {
            guard let agent = agents.first(where: { $0.id == agentId }),
                  let response = task.responses[agentId] else { continue }

            sections.append("[\(agent.name) - \(agent.role)]\n\(response)")
        }
        return sections.joined(separator: "\n\n---\n\n")
    }
}
