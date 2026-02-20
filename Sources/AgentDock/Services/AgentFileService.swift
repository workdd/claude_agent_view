import Foundation

class AgentFileService {
    private let agentsDirectory: URL
    private var fileMonitor: DispatchSourceFileSystemObject?
    var onAgentsChanged: (([Agent]) -> Void)?

    init(agentsDirectory: URL? = nil) {
        self.agentsDirectory = agentsDirectory ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude/agents")
    }

    // MARK: - Load Agents

    func loadAgents() -> [Agent] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: agentsDirectory.path) else {
            return Agent.defaultAgents
        }

        do {
            let files = try fm.contentsOfDirectory(at: agentsDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "md" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            let agents = files.compactMap { parseAgentFile($0) }
            return agents.isEmpty ? Agent.defaultAgents : agents
        } catch {
            return Agent.defaultAgents
        }
    }

    // MARK: - Parse Agent File

    private func parseAgentFile(_ url: URL) -> Agent? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let (frontmatter, body) = splitFrontmatter(content)
        guard let fm = frontmatter else { return nil }

        let fields = parseFrontmatterFields(fm)
        guard let name = fields["name"] else { return nil }

        let description = fields["description"] ?? ""
        let tools = parseCommaSeparated(fields["tools"] ?? "")
        let model = fields["model"] ?? "sonnet"
        let skills = parseCommaSeparated(fields["skills"] ?? "")

        let character = Agent.characterFor(name: name)
        let systemPrompt = body.trimmingCharacters(in: .whitespacesAndNewlines)

        return Agent(
            name: name.capitalized,
            role: deriveRole(from: description, name: name),
            character: character,
            systemPrompt: systemPrompt,
            agentDescription: description,
            tools: tools,
            model: model,
            skills: skills,
            filePath: url.path
        )
    }

    // MARK: - Frontmatter Parsing

    private func splitFrontmatter(_ content: String) -> (String?, String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return (nil, content) }

        let afterFirst = String(trimmed.dropFirst(3))
        guard let endRange = afterFirst.range(of: "\n---") else { return (nil, content) }

        let frontmatter = String(afterFirst[afterFirst.startIndex..<endRange.lowerBound])
        let body = String(afterFirst[endRange.upperBound...])
        return (frontmatter, body)
    }

    private func parseFrontmatterFields(_ text: String) -> [String: String] {
        var fields: [String: String] = [:]
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let colonIndex = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[trimmed.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty {
                fields[key] = value
            }
        }
        return fields
    }

    private func parseCommaSeparated(_ text: String) -> [String] {
        text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func deriveRole(from description: String, name: String) -> String {
        // Extract a short role from description
        let lower = name.lowercased()
        if lower.contains("backend") { return "Backend Developer" }
        if lower.contains("frontend") { return "Frontend Designer" }
        if lower.contains("researcher") || lower.contains("research") { return "Tech Researcher" }

        // Fallback: use first clause of description
        if let dotIndex = description.firstIndex(of: ".") {
            let firstSentence = String(description[description.startIndex..<dotIndex])
            if firstSentence.count < 50 { return firstSentence }
        }
        return "Agent"
    }

    // MARK: - File Watching

    func startWatching() {
        let fd = open(agentsDirectory.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let agents = self.loadAgents()
            self.onAgentsChanged?(agents)
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        fileMonitor = source
    }

    func stopWatching() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    // MARK: - Create Custom Agent

    func createAgent(
        name: String,
        description: String,
        tools: [String],
        model: String,
        skills: [String],
        systemPrompt: String
    ) throws {
        let fm = FileManager.default

        // Ensure directory exists
        if !fm.fileExists(atPath: agentsDirectory.path) {
            try fm.createDirectory(at: agentsDirectory, withIntermediateDirectories: true)
        }

        let fileName = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
        let fileURL = agentsDirectory.appendingPathComponent("\(fileName).md")

        var content = "---\n"
        content += "name: \(name.lowercased())\n"
        content += "description: \(description)\n"
        if !tools.isEmpty {
            content += "tools: \(tools.joined(separator: ", "))\n"
        }
        content += "model: \(model)\n"
        if !skills.isEmpty {
            content += "skills: \(skills.joined(separator: ", "))\n"
        }
        content += "---\n\n"
        content += systemPrompt

        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Delete Agent File

    func deleteAgent(filePath: String) throws {
        try FileManager.default.removeItem(atPath: filePath)
    }
}
