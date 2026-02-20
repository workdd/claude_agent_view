import Foundation
import Observation

@Observable
class AgentViewModel {
    var agents: [Agent] = []
    var claudeService: ClaudeService?
    var cliService = ClaudeCLIService()
    var useSubscription: Bool = true
    var activeTasks: [CollaborationTask] = []

    private let agentFileService = AgentFileService()

    init() {
        agents = agentFileService.loadAgents()

        if let apiKey = KeychainService.load(key: "anthropic-api-key") {
            claudeService = ClaudeService(apiKey: apiKey)
        }

        agentFileService.onAgentsChanged = { [weak self] newAgents in
            self?.agents = newAgents
        }
        agentFileService.startWatching()
    }

    deinit {
        agentFileService.stopWatching()
    }

    // MARK: - Team Context (Supervisor Architecture)

    /// Builds a context string that makes the agent aware of its role,
    /// the team structure, and the user as supervisor.
    private func teamContext(for agent: Agent) -> String {
        let otherAgents = agents.filter { $0.id != agent.id }
            .map { "- \($0.name) (\($0.role))" }
            .joined(separator: "\n")

        return """

        [Team Context]
        You are \(agent.name), the \(agent.role) in a multi-agent team.
        Your specialization: \(agent.agentDescription)
        Model: \(agent.model)
        Available tools: \(agent.tools.joined(separator: ", "))

        The USER is the Supervisor who coordinates all agents.
        When the Supervisor gives you a task, focus on your area of expertise.

        Other team members:
        \(otherAgents)

        If a task falls outside your expertise, suggest which team member
        would be better suited. Always be concise and action-oriented.
        """
    }

    // MARK: - Send Message (single agent)

    func sendMessage(to agentId: UUID, content: String) async {
        guard let index = agents.firstIndex(where: { $0.id == agentId }) else { return }

        let userMessage = ChatMessage(role: .user, content: content)
        agents[index].messages.append(userMessage)
        agents[index].status = .thinking

        // Build full system prompt with team context
        let fullSystemPrompt = agents[index].systemPrompt + teamContext(for: agents[index])

        if useSubscription && cliService.isAvailable {
            await sendViaCLI(index: index, content: content, systemPrompt: fullSystemPrompt)
        } else if let service = claudeService {
            await sendViaAPI(index: index, content: content, service: service, systemPrompt: fullSystemPrompt)
        } else {
            let errorMsg = ChatMessage(role: .assistant, content: "No connection. Open Settings to configure Claude subscription or API key.")
            agents[index].messages.append(errorMsg)
            agents[index].status = .idle
        }
    }

    private func sendViaCLI(index: Int, content: String, systemPrompt: String) async {
        agents[index].status = .working
        do {
            let response = try await cliService.sendMessage(
                prompt: content,
                systemPrompt: systemPrompt
            )
            let msg = ChatMessage(role: .assistant, content: response)
            agents[index].messages.append(msg)
            agents[index].status = .idle
        } catch {
            agents[index].status = .idle
            let errorMsg = ChatMessage(role: .assistant, content: "CLI Error: \(error.localizedDescription)")
            agents[index].messages.append(errorMsg)
        }
    }

    private func sendViaAPI(index: Int, content: String, service: ClaudeService, systemPrompt: String) async {
        do {
            var fullResponse = ""
            let placeholder = ChatMessage(role: .assistant, content: "")
            agents[index].messages.append(placeholder)
            let responseIndex = agents[index].messages.count - 1
            agents[index].status = .working

            let stream = service.streamMessage(
                messages: Array(agents[index].messages.dropLast()),
                systemPrompt: systemPrompt
            )

            for try await text in stream {
                fullResponse += text
                agents[index].messages[responseIndex] = ChatMessage(
                    id: placeholder.id,
                    role: .assistant,
                    content: fullResponse,
                    timestamp: placeholder.timestamp
                )
            }

            agents[index].status = .idle
        } catch {
            agents[index].status = .idle
            let errorMsg = ChatMessage(role: .assistant, content: "API Error: \(error.localizedDescription)")
            agents[index].messages.append(errorMsg)
        }
    }

    // MARK: - Collaboration (multi-agent)

    func sendCollaborativeMessage(content: String) async {
        let (cleanMessage, mentionedIds) = CollaborationService.parseMentions(
            from: content, agents: agents
        )

        guard mentionedIds.count > 1 else {
            if let firstId = mentionedIds.first {
                await sendMessage(to: firstId, content: cleanMessage)
            }
            return
        }

        var task = CollaborationTask(message: cleanMessage, targetAgentIds: mentionedIds)
        task.status = .inProgress
        activeTasks.append(task)
        let taskIndex = activeTasks.count - 1

        await withTaskGroup(of: (UUID, String).self) { group in
            for agentId in mentionedIds {
                guard let agentIndex = agents.firstIndex(where: { $0.id == agentId }) else { continue }
                let agent = agents[agentIndex]
                let colabContext = CollaborationService.collaborationContext(
                    currentAgent: agent,
                    allAgents: agents,
                    mentionedIds: mentionedIds
                )
                let augmentedPrompt = agent.systemPrompt + teamContext(for: agent) + colabContext

                group.addTask { [weak self] in
                    guard let self, let service = self.claudeService else {
                        return (agentId, "Error: No API key")
                    }

                    await MainActor.run {
                        if let idx = self.agents.firstIndex(where: { $0.id == agentId }) {
                            self.agents[idx].status = .working
                        }
                    }

                    do {
                        let messages = [ChatMessage(role: .user, content: cleanMessage)]
                        let response = try await service.sendMessage(
                            messages: messages,
                            systemPrompt: augmentedPrompt
                        )

                        await MainActor.run {
                            if let idx = self.agents.firstIndex(where: { $0.id == agentId }) {
                                self.agents[idx].status = .idle
                            }
                        }

                        return (agentId, response)
                    } catch {
                        await MainActor.run {
                            if let idx = self.agents.firstIndex(where: { $0.id == agentId }) {
                                self.agents[idx].status = .idle
                            }
                        }
                        return (agentId, "Error: \(error.localizedDescription)")
                    }
                }
            }

            for await (agentId, response) in group {
                activeTasks[taskIndex].responses[agentId] = response
            }
        }

        activeTasks[taskIndex].status = .complete

        let combined = CollaborationService.formatCombinedResponse(
            task: activeTasks[taskIndex],
            agents: agents
        )

        for agentId in mentionedIds {
            guard let index = agents.firstIndex(where: { $0.id == agentId }) else { continue }
            let userMsg = ChatMessage(role: .user, content: "[Collab] \(cleanMessage)")
            let assistantMsg = ChatMessage(role: .assistant, content: combined)
            agents[index].messages.append(userMsg)
            agents[index].messages.append(assistantMsg)
        }
    }

    // MARK: - Custom Agent Management

    func createCustomAgent(
        name: String,
        description: String,
        tools: [String],
        model: String,
        skills: [String],
        systemPrompt: String
    ) throws {
        try agentFileService.createAgent(
            name: name,
            description: description,
            tools: tools,
            model: model,
            skills: skills,
            systemPrompt: systemPrompt
        )
        // File watcher will auto-pick up the new agent
    }

    func deleteAgent(filePath: String) throws {
        try agentFileService.deleteAgent(filePath: filePath)
    }

    // MARK: - Settings

    func setApiKey(_ key: String) {
        KeychainService.save(key: "anthropic-api-key", value: key)
        claudeService = ClaudeService(apiKey: key)
    }

    var hasApiKey: Bool {
        claudeService != nil
    }

    func reloadAgentsFromDisk() {
        let newAgents = agentFileService.loadAgents()
        for i in agents.indices {
            if let match = newAgents.firstIndex(where: { $0.name == agents[i].name }) {
                var updated = newAgents[match]
                updated.messages = agents[i].messages
                updated.status = agents[i].status
                agents[i] = updated
            }
        }
        for newAgent in newAgents {
            if !agents.contains(where: { $0.name == newAgent.name }) {
                agents.append(newAgent)
            }
        }
    }
}
