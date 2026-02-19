import Foundation

/// Reads all Claude Code configuration: agents, skills, settings, MCP plugins
class ClaudeCodeSyncService {

    private let claudeDir: URL

    init() {
        self.claudeDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude")
    }

    // MARK: - Skills

    struct SkillInfo: Identifiable {
        let id = UUID()
        let name: String
        let source: String  // agent name or "global"
    }

    /// Read skills from all agent .md files + global settings
    func loadSkills() -> [SkillInfo] {
        var skills: [SkillInfo] = []

        // Parse skills from agent .md files
        let agentsDir = claudeDir.appendingPathComponent("agents")
        if let files = try? FileManager.default.contentsOfDirectory(at: agentsDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "md" {
                guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let (frontmatter, _) = splitFrontmatter(content)
                guard let fm = frontmatter else { continue }
                let fields = parseFrontmatterFields(fm)
                let agentName = fields["name"] ?? file.deletingPathExtension().lastPathComponent
                let agentSkills = parseCommaSeparated(fields["skills"] ?? "")
                for skill in agentSkills {
                    skills.append(SkillInfo(name: skill, source: agentName))
                }
            }
        }

        return skills
    }

    // MARK: - MCP Plugins

    struct MCPPlugin: Identifiable {
        let id = UUID()
        let name: String
        let command: String
        let args: [String]
    }

    func loadMCPPlugins() -> [MCPPlugin] {
        // Check .mcp.json in home directory
        let mcpPaths = [
            claudeDir.appendingPathComponent(".mcp.json"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".mcp.json"),
        ]

        for path in mcpPaths {
            if let plugins = parseMCPConfig(at: path) {
                return plugins
            }
        }
        return []
    }

    private func parseMCPConfig(at url: URL) -> [MCPPlugin]? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["mcpServers"] as? [String: Any]
        else { return nil }

        var plugins: [MCPPlugin] = []
        for (name, config) in servers {
            guard let cfg = config as? [String: Any] else { continue }
            let command = cfg["command"] as? String ?? ""
            let args = cfg["args"] as? [String] ?? []
            plugins.append(MCPPlugin(name: name, command: command, args: args))
        }
        return plugins
    }

    // MARK: - Claude Code Settings

    struct ClaudeSettings {
        let model: String
        let customInstructions: String
        let permissions: [String: Any]
    }

    func loadSettings() -> ClaudeSettings? {
        let settingsPath = claudeDir.appendingPathComponent("settings.json")
        guard let data = try? Data(contentsOf: settingsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        return ClaudeSettings(
            model: json["model"] as? String ?? "unknown",
            customInstructions: json["customInstructions"] as? String ?? "",
            permissions: json["permissions"] as? [String: Any] ?? [:]
        )
    }

    // MARK: - CLAUDE.md Files

    struct ClaudeMD: Identifiable {
        let id = UUID()
        let path: String
        let scope: String  // "global", "project", "memory"
        let content: String
        var preview: String {
            String(content.prefix(200))
        }
    }

    func loadClaudeMDFiles() -> [ClaudeMD] {
        var files: [ClaudeMD] = []

        // Global CLAUDE.md
        let globalPath = claudeDir.appendingPathComponent("CLAUDE.md")
        if let content = try? String(contentsOf: globalPath, encoding: .utf8) {
            files.append(ClaudeMD(path: globalPath.path, scope: "global", content: content))
        }

        // Home CLAUDE.md
        let homePath = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("CLAUDE.md")
        if let content = try? String(contentsOf: homePath, encoding: .utf8) {
            files.append(ClaudeMD(path: homePath.path, scope: "project", content: content))
        }

        // Memory CLAUDE.md
        let memoryDir = claudeDir.appendingPathComponent("projects")
        if let projectDirs = try? FileManager.default.contentsOfDirectory(at: memoryDir, includingPropertiesForKeys: nil) {
            for dir in projectDirs {
                let memPath = dir.appendingPathComponent("memory/MEMORY.md")
                if let content = try? String(contentsOf: memPath, encoding: .utf8) {
                    files.append(ClaudeMD(path: memPath.path, scope: "memory", content: content))
                }
            }
        }

        return files
    }

    // MARK: - Frontmatter Parsing (shared)

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
            if !key.isEmpty { fields[key] = value }
        }
        return fields
    }

    private func parseCommaSeparated(_ text: String) -> [String] {
        text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
