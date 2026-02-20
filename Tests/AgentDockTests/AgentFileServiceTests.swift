import Testing
import Foundation
@testable import AgentDock

@Suite("AgentFileService")
struct AgentFileServiceTests {

    // MARK: - Helpers

    /// Creates a temporary directory and returns (URL, AgentFileService).
    /// Callers are responsible for removing the directory after use.
    static func makeTempService() -> (URL, AgentFileService) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentDockTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (dir, AgentFileService(agentsDirectory: dir))
    }

    static func removeTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func writeAgentMd(to dir: URL, name: String, description: String = "desc",
                              tools: String = "", model: String = "sonnet",
                              skills: String = "", systemPrompt: String = "Prompt.") throws {
        var content = "---\n"
        content += "name: \(name)\n"
        content += "description: \(description)\n"
        if !tools.isEmpty { content += "tools: \(tools)\n" }
        content += "model: \(model)\n"
        if !skills.isEmpty { content += "skills: \(skills)\n" }
        content += "---\n\n\(systemPrompt)"

        let fileURL = dir.appendingPathComponent("\(name).md")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - loadAgents Tests

    @Test("loadAgents on empty directory returns default agents")
    func loadAgents_emptyDirectory_returnsDefaults() {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        let agents = svc.loadAgents()
        #expect(agents.count == Agent.defaultAgents.count)
    }

    @Test("loadAgents on non-existent directory returns default agents")
    func loadAgents_nonExistentDirectory_returnsDefaults() {
        let nonExistent = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-such-dir-\(UUID().uuidString)")
        let svc = AgentFileService(agentsDirectory: nonExistent)
        let agents = svc.loadAgents()
        #expect(agents.count == Agent.defaultAgents.count)
    }

    @Test("loadAgents with valid .md file returns parsed agent")
    func loadAgents_withValidMdFile_returnsParsedAgent() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        try Self.writeAgentMd(to: dir, name: "tester", description: "A dedicated testing agent.",
                              tools: "Read, Bash", systemPrompt: "You are a test specialist.")

        let agents = svc.loadAgents()
        #expect(agents.count == 1)
        #expect(agents.first?.name == "Tester")
    }

    @Test("loadAgents with missing name field returns default agents")
    func loadAgents_missingNameField_returnsDefaults() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        let content = "---\ndescription: No name.\nmodel: sonnet\n---\nPrompt."
        try content.write(to: dir.appendingPathComponent("noname.md"),
                          atomically: true, encoding: .utf8)

        let agents = svc.loadAgents()
        #expect(agents.count == Agent.defaultAgents.count)
    }

    @Test("loadAgents ignores non-.md files")
    func loadAgents_ignoresNonMdFiles() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        try Self.writeAgentMd(to: dir, name: "valid")
        try "not markdown".write(to: dir.appendingPathComponent("readme.txt"),
                                  atomically: true, encoding: .utf8)

        let agents = svc.loadAgents()
        #expect(agents.count == 1)
        #expect(agents.first?.name == "Valid")
    }

    @Test("loadAgents agent has correct tools")
    func loadAgents_agentHasCorrectTools() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        try Self.writeAgentMd(to: dir, name: "toolagent", tools: "Read, Write, Bash")
        let agents = svc.loadAgents()

        guard let agent = agents.first else {
            Issue.record("Expected one agent")
            return
        }
        #expect(agent.tools.contains("Read"))
        #expect(agent.tools.contains("Write"))
        #expect(agent.tools.contains("Bash"))
    }

    @Test("loadAgents agent has correct model")
    func loadAgents_agentHasCorrectModel() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        try Self.writeAgentMd(to: dir, name: "opusagent", model: "opus")
        let agents = svc.loadAgents()
        #expect(agents.first?.model == "opus")
    }

    @Test("loadAgents with multiple .md files returns all agents")
    func loadAgents_multipleMdFiles_returnsAll() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        for i in 1...3 {
            try Self.writeAgentMd(to: dir, name: "agent\(i)",
                                   description: "Agent number \(i).",
                                   systemPrompt: "Prompt \(i).")
        }

        let agents = svc.loadAgents()
        #expect(agents.count == 3)
    }

    // MARK: - createAgent Tests

    @Test("createAgent creates file on disk")
    func createAgent_createsFileOnDisk() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        try svc.createAgent(name: "newagent", description: "A new agent",
                             tools: ["Read"], model: "sonnet", skills: [],
                             systemPrompt: "You are new.")

        let expectedPath = dir.appendingPathComponent("newagent.md")
        #expect(FileManager.default.fileExists(atPath: expectedPath.path))
    }

    @Test("createAgent file contains YAML frontmatter delimiters")
    func createAgent_fileContainsFrontmatter() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        try svc.createAgent(name: "frontmattertest", description: "Test frontmatter",
                             tools: ["Read", "Write"], model: "haiku", skills: ["swift"],
                             systemPrompt: "Frontmatter agent prompt.")

        let fileURL = dir.appendingPathComponent("frontmattertest.md")
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        #expect(content.contains("---"))
        #expect(content.contains("name: frontmattertest"))
        #expect(content.contains("description: Test frontmatter"))
        #expect(content.contains("model: haiku"))
    }

    @Test("createAgent file contains system prompt")
    func createAgent_fileContainsSystemPrompt() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        let prompt = "You are a system prompt agent."
        try svc.createAgent(name: "prompttest", description: "desc",
                             tools: [], model: "sonnet", skills: [], systemPrompt: prompt)

        let fileURL = dir.appendingPathComponent("prompttest.md")
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(content.contains(prompt))
    }

    @Test("createAgent normalises spaces in name to hyphens")
    func createAgent_nameWithSpaces_usesHyphens() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        try svc.createAgent(name: "my agent", description: "desc",
                             tools: [], model: "sonnet", skills: [], systemPrompt: "p")

        let expectedPath = dir.appendingPathComponent("my-agent.md")
        #expect(FileManager.default.fileExists(atPath: expectedPath.path))
    }

    @Test("createAgent normalises underscores in name to hyphens")
    func createAgent_nameWithUnderscores_usesHyphens() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        try svc.createAgent(name: "my_agent", description: "desc",
                             tools: [], model: "sonnet", skills: [], systemPrompt: "p")

        let expectedPath = dir.appendingPathComponent("my-agent.md")
        #expect(FileManager.default.fileExists(atPath: expectedPath.path))
    }

    @Test("createAgent with tools writes tools line to file")
    func createAgent_withTools_writesToolsLine() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        try svc.createAgent(name: "tooltest", description: "desc",
                             tools: ["Read", "Write", "Bash"], model: "sonnet",
                             skills: [], systemPrompt: "p")

        let fileURL = dir.appendingPathComponent("tooltest.md")
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(content.contains("tools: Read, Write, Bash"))
    }

    @Test("createAgent with empty tools omits tools line")
    func createAgent_withEmptyTools_omitsToolsLine() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        try svc.createAgent(name: "notooltest", description: "desc",
                             tools: [], model: "sonnet", skills: [], systemPrompt: "p")

        let fileURL = dir.appendingPathComponent("notooltest.md")
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(!content.contains("tools:"))
    }

    @Test("createAgent then loadAgents returns the created agent")
    func createAgent_thenLoadAgents_agentIsReadBack() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        try svc.createAgent(name: "roundtrip", description: "Round-trip test agent",
                             tools: ["Read"], model: "sonnet", skills: [],
                             systemPrompt: "You test round-trips.")

        let agents = svc.loadAgents()
        #expect(agents.contains { $0.name == "Roundtrip" })
    }

    // MARK: - deleteAgent Tests

    @Test("deleteAgent removes the file from disk")
    func deleteAgent_removesFile() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        let fileURL = dir.appendingPathComponent("todelete.md")
        try "content".write(to: fileURL, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        try svc.deleteAgent(filePath: fileURL.path)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("deleteAgent throws when file does not exist")
    func deleteAgent_nonExistentFile_throws() {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        let fakePath = dir.appendingPathComponent("nonexistent.md").path
        #expect(throws: (any Error).self) {
            try svc.deleteAgent(filePath: fakePath)
        }
    }

    @Test("createAgent then deleteAgent leaves no file on disk")
    func createThenDeleteAgent_fileGone() throws {
        let (dir, svc) = Self.makeTempService()
        defer { Self.removeTempDirectory(dir) }

        try svc.createAgent(name: "deleteme", description: "Will be deleted",
                             tools: [], model: "sonnet", skills: [], systemPrompt: "Temporary.")

        let fileURL = dir.appendingPathComponent("deleteme.md")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        try svc.deleteAgent(filePath: fileURL.path)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }
}
