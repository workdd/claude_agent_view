import Foundation
import Observation

@Observable
class AgentViewModel {
    var agents: [Agent] = []
    var claudeService: ClaudeService?
    var cliService = ClaudeCLIService()
    var useSubscription: Bool = true  // prefer CLI subscription by default
    var activeTasks: [CollaborationTask] = []

    private let agentFileService = AgentFileService()

    init() {
        // Load agents from ~/.claude/agents/ first, fallback to defaults
        agents = agentFileService.loadAgents()

        if let apiKey = KeychainService.load(key: "anthropic-api-key") {
            claudeService = ClaudeService(apiKey: apiKey)
        }

        // Watch for agent file changes
        agentFileService.onAgentsChanged = { [weak self] newAgents in
            self?.agents = newAgents
        }
        agentFileService.startWatching()
    }

    deinit {
        agentFileService.stopWatching()
    }

    // MARK: - Send Message (single agent)

    func sendMessage(to agentId: UUID, content: String) async {
        guard let index = agents.firstIndex(where: { $0.id == agentId }) else { return }

        let userMessage = ChatMessage(role: .user, content: content)
        agents[index].messages.append(userMessage)
        agents[index].status = .thinking

        // Route to CLI subscription or API key
        if useSubscription && cliService.isAvailable {
            await sendViaCLI(index: index, content: content)
        } else if let service = claudeService {
            await sendViaAPI(index: index, content: content, service: service)
        } else {
            let errorMsg = ChatMessage(role: .assistant, content: "No connection. Open Settings to configure Claude subscription or API key.")
            agents[index].messages.append(errorMsg)
            agents[index].status = .idle
        }
    }

    private func sendViaCLI(index: Int, content: String) async {
        agents[index].status = .working
        do {
            let response = try await cliService.sendMessage(
                prompt: content,
                systemPrompt: agents[index].systemPrompt
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

    private func sendViaAPI(index: Int, content: String, service: ClaudeService) async {
        do {
            var fullResponse = ""
            let placeholder = ChatMessage(role: .assistant, content: "")
            agents[index].messages.append(placeholder)
            let responseIndex = agents[index].messages.count - 1
            agents[index].status = .working

            let stream = service.streamMessage(
                messages: Array(agents[index].messages.dropLast()),
                systemPrompt: agents[index].systemPrompt
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

        // If no mentions, this is not a collab message
        guard mentionedIds.count > 1 else {
            // Single agent or no mentions — route to first mentioned or skip
            if let firstId = mentionedIds.first {
                await sendMessage(to: firstId, content: cleanMessage)
            }
            return
        }

        var task = CollaborationTask(message: cleanMessage, targetAgentIds: mentionedIds)
        task.status = .inProgress
        activeTasks.append(task)
        let taskIndex = activeTasks.count - 1

        // Send to all mentioned agents concurrently
        await withTaskGroup(of: (UUID, String).self) { group in
            for agentId in mentionedIds {
                guard let agentIndex = agents.firstIndex(where: { $0.id == agentId }) else { continue }
                let agent = agents[agentIndex]
                let colabContext = CollaborationService.collaborationContext(
                    currentAgent: agent,
                    allAgents: agents,
                    mentionedIds: mentionedIds
                )
                let augmentedPrompt = agent.systemPrompt + colabContext

                group.addTask { [weak self] in
                    guard let self, let service = self.claudeService else {
                        return (agentId, "Error: No API key")
                    }

                    // Mark agent working
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

        // Format combined response and add to each agent's chat
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
        // Preserve messages and status from current agents
        for i in agents.indices {
            if let match = newAgents.firstIndex(where: { $0.name == agents[i].name }) {
                var updated = newAgents[match]
                updated.messages = agents[i].messages
                updated.status = agents[i].status
                agents[i] = updated
            }
        }
        // Add any new agents
        for newAgent in newAgents {
            if !agents.contains(where: { $0.name == newAgent.name }) {
                agents.append(newAgent)
            }
        }
    }
}
