import Testing
import Foundation
@testable import AgentDock

// MARK: - AgentModel Tests

@Suite("Agent Model")
struct AgentModelTests {

    // MARK: - characterFor Tests

    @Test("characterFor known name 'backend' returns 'bear'")
    func characterFor_backend_returnsBear() {
        let result = Agent.characterFor(name: "backend")
        #expect(result == "bear")
    }

    @Test("characterFor known name 'frontend-designer' returns 'pig'")
    func characterFor_frontendDesigner_returnsPig() {
        let result = Agent.characterFor(name: "frontend-designer")
        #expect(result == "pig")
    }

    @Test("characterFor known name 'researcher' returns 'cat'")
    func characterFor_researcher_returnsCat() {
        let result = Agent.characterFor(name: "researcher")
        #expect(result == "cat")
    }

    @Test("characterFor unknown name returns a valid animal")
    func characterFor_unknownName_returnsValidAnimal() {
        let validAnimals = ["bear", "pig", "cat"]
        let result = Agent.characterFor(name: "devops-specialist")
        #expect(validAnimals.contains(result))
    }

    @Test("characterFor empty name does not crash and returns valid animal")
    func characterFor_emptyName_returnsValidAnimal() {
        let validAnimals = ["bear", "pig", "cat"]
        let result = Agent.characterFor(name: "")
        #expect(validAnimals.contains(result))
    }

    @Test("characterFor is case insensitive for known names")
    func characterFor_caseInsensitive() {
        let lower = Agent.characterFor(name: "backend")
        let upper = Agent.characterFor(name: "BACKEND")
        #expect(lower == upper)
    }

    // MARK: - Default Agents Tests

    @Test("defaultAgents count is 3")
    func defaultAgents_count() {
        #expect(Agent.defaultAgents.count == 3)
    }

    @Test("defaultAgents contains Backend")
    func defaultAgents_containsBackend() {
        let names = Agent.defaultAgents.map { $0.name }
        #expect(names.contains("Backend"))
    }

    @Test("defaultAgents contains Frontend")
    func defaultAgents_containsFrontend() {
        let names = Agent.defaultAgents.map { $0.name }
        #expect(names.contains("Frontend"))
    }

    @Test("defaultAgents contains Researcher")
    func defaultAgents_containsResearcher() {
        let names = Agent.defaultAgents.map { $0.name }
        #expect(names.contains("Researcher"))
    }

    @Test("defaultAgents Backend character is bear")
    func defaultAgents_backendIsBear() {
        let backend = Agent.defaultAgents.first { $0.name == "Backend" }
        #expect(backend?.character == "bear")
    }

    @Test("defaultAgents Frontend character is pig")
    func defaultAgents_frontendIsPig() {
        let frontend = Agent.defaultAgents.first { $0.name == "Frontend" }
        #expect(frontend?.character == "pig")
    }

    @Test("defaultAgents Researcher character is cat")
    func defaultAgents_researcherIsCat() {
        let researcher = Agent.defaultAgents.first { $0.name == "Researcher" }
        #expect(researcher?.character == "cat")
    }

    @Test("defaultAgents all have non-empty system prompts")
    func defaultAgents_haveNonEmptySystemPrompts() {
        for agent in Agent.defaultAgents {
            #expect(!agent.systemPrompt.isEmpty, "Agent '\(agent.name)' has empty systemPrompt")
        }
    }

    @Test("defaultAgents all have tools")
    func defaultAgents_haveTools() {
        for agent in Agent.defaultAgents {
            #expect(!agent.tools.isEmpty, "Agent '\(agent.name)' has no tools")
        }
    }

    @Test("defaultAgents all use sonnet model")
    func defaultAgents_defaultModelIsSonnet() {
        for agent in Agent.defaultAgents {
            #expect(agent.model == "sonnet")
        }
    }

    @Test("defaultAgents default status is idle")
    func defaultAgents_defaultStatusIsIdle() {
        for agent in Agent.defaultAgents {
            #expect(agent.status == .idle)
        }
    }

    @Test("defaultAgents messages are empty by default")
    func defaultAgents_defaultMessagesEmpty() {
        for agent in Agent.defaultAgents {
            #expect(agent.messages.isEmpty)
        }
    }

    // MARK: - Agent Init Tests

    @Test("Agent init default values are correct")
    func agent_init_defaultValues() {
        let agent = Agent(
            name: "TestAgent",
            role: "Tester",
            character: "bear",
            systemPrompt: "You are a test agent."
        )

        #expect(agent.name == "TestAgent")
        #expect(agent.role == "Tester")
        #expect(agent.character == "bear")
        #expect(agent.systemPrompt == "You are a test agent.")
        #expect(agent.status == .idle)
        #expect(agent.messages.isEmpty)
        #expect(agent.model == "sonnet")
        #expect(agent.tools.isEmpty)
        #expect(agent.skills.isEmpty)
        #expect(agent.filePath == nil)
    }

    @Test("Agent init with custom UUID preserves it")
    func agent_init_customId_preserved() {
        let fixedId = UUID()
        let agent = Agent(id: fixedId, name: "Fixed", role: "Role", character: "cat", systemPrompt: "p")
        #expect(agent.id == fixedId)
    }

    @Test("Two agents with same params have different UUIDs")
    func agent_uniqueIds() {
        let a1 = Agent(name: "A", role: "r", character: "bear", systemPrompt: "p")
        let a2 = Agent(name: "A", role: "r", character: "bear", systemPrompt: "p")
        #expect(a1.id != a2.id)
    }

    // MARK: - AgentStatus Tests

    @Test("AgentStatus has 3 cases")
    func agentStatus_allCases_count() {
        #expect(AgentStatus.allCases.count == 3)
    }

    @Test("AgentStatus raw values are correct")
    func agentStatus_rawValues() {
        #expect(AgentStatus.idle.rawValue == "idle")
        #expect(AgentStatus.working.rawValue == "working")
        #expect(AgentStatus.thinking.rawValue == "thinking")
    }

    // MARK: - Character Map Tests

    @Test("characterMap contains expected keys")
    func characterMap_containsExpectedKeys() {
        let map = Agent.characterMap
        #expect(map["backend"] != nil)
        #expect(map["frontend-designer"] != nil)
        #expect(map["researcher"] != nil)
    }

    @Test("characterMap values are valid animals")
    func characterMap_valuesAreValidAnimals() {
        let validAnimals = Set(["bear", "pig", "cat"])
        for (_, animal) in Agent.characterMap {
            #expect(validAnimals.contains(animal), "'\(animal)' is not a valid animal")
        }
    }
}
