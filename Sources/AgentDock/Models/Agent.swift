import Foundation

enum AgentStatus: String, CaseIterable {
    case idle
    case working
    case thinking
}

struct Agent: Identifiable {
    let id: UUID
    var name: String
    var role: String
    var character: String  // bear / pig / cat
    var systemPrompt: String
    var status: AgentStatus
    var messages: [ChatMessage]

    // Extended fields from .md agent definitions
    var agentDescription: String
    var tools: [String]
    var model: String
    var skills: [String]
    var filePath: String?  // path to the .md file on disk

    init(
        id: UUID = UUID(),
        name: String,
        role: String,
        character: String,
        systemPrompt: String,
        status: AgentStatus = .idle,
        messages: [ChatMessage] = [],
        agentDescription: String = "",
        tools: [String] = [],
        model: String = "sonnet",
        skills: [String] = [],
        filePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.character = character
        self.systemPrompt = systemPrompt
        self.status = status
        self.messages = messages
        self.agentDescription = agentDescription
        self.tools = tools
        self.model = model
        self.skills = skills
        self.filePath = filePath
    }
}

// MARK: - Character Mapping
extension Agent {
    static let characterMap: [String: String] = [
        "backend": "bear",
        "frontend-designer": "pig",
        "researcher": "cat",
    ]

    static func characterFor(name: String) -> String {
        let animals = ["bear", "pig", "cat"]
        if let mapped = characterMap[name.lowercased()] {
            return mapped
        }
        // Hash-based assignment for unknown agents
        let hash = abs(name.hashValue)
        return animals[hash % animals.count]
    }
}

// MARK: - Default Agents (fallback when no .md files found)
extension Agent {
    static let defaultAgents: [Agent] = [
        Agent(
            name: "Backend",
            role: "Backend Developer",
            character: "bear",
            systemPrompt: """
            You are a backend development specialist. \
            You handle REST API, GraphQL, database design, authentication, \
            performance optimization, microservices, and infrastructure code.
            """,
            agentDescription: "Backend API and server development agent",
            tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash"],
            model: "sonnet"
        ),
        Agent(
            name: "Frontend",
            role: "Frontend Designer",
            character: "pig",
            systemPrompt: """
            You are a UI/UX design and frontend development specialist. \
            You handle component design, styling, responsive layouts, accessibility, \
            animations, and design system architecture.
            """,
            agentDescription: "UI/UX design and frontend development agent",
            tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash"],
            model: "sonnet"
        ),
        Agent(
            name: "Researcher",
            role: "Tech Researcher",
            character: "cat",
            systemPrompt: """
            You are a technical research and documentation specialist. \
            You handle paper analysis, technology trend research, competitor analysis, \
            library/framework comparisons, and architecture decision records.
            """,
            agentDescription: "Technical research and documentation agent",
            tools: ["Read", "Write", "Glob", "Grep", "WebFetch", "WebSearch"],
            model: "sonnet"
        ),
    ]
}
