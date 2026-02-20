import Foundation

/// Uses the locally installed `claude` CLI (authenticated via Claude subscription)
/// Supports full team agent mode: persistent sessions, tool use, streaming.
class ClaudeCLIService {

    private let claudePath: String

    /// Per-agent session IDs for conversation persistence
    private var agentSessions: [String: String] = [:]

    init() {
        self.claudePath = ClaudeCLIService.findClaudePath() ?? "/usr/local/bin/claude"
    }

    var isAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: claudePath)
    }

    // MARK: - Auth Status (OAuth integration)

    struct AuthStatus {
        let loggedIn: Bool
        let authMethod: String
        let email: String?
        let orgName: String?
        let subscriptionType: String?
    }

    /// Build a clean environment for subprocess
    private func cleanEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "dumb"
        env.removeValue(forKey: "CLAUDECODE")
        env.removeValue(forKey: "CLAUDE_CODE_ENTRYPOINT")
        env.removeValue(forKey: "ANTHROPIC_API_KEY")
        let extraPaths = [
            "\(NSHomeDirectory())/.local/bin",
            "\(NSHomeDirectory())/.nvm/versions/node/v22.0.0/bin",
            "\(NSHomeDirectory())/.nvm/versions/node/v20.0.0/bin",
            "/usr/local/bin",
            "/opt/homebrew/bin",
        ]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (extraPaths + [currentPath]).joined(separator: ":")
        return env
    }

    func checkAuthStatus() -> AuthStatus {
        guard isAvailable else {
            return AuthStatus(loggedIn: false, authMethod: "none", email: nil, orgName: nil, subscriptionType: nil)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = ["auth", "status"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        process.standardInput = FileHandle.nullDevice
        process.environment = cleanEnvironment()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return AuthStatus(loggedIn: false, authMethod: "unknown", email: nil, orgName: nil, subscriptionType: nil)
            }

            return AuthStatus(
                loggedIn: json["loggedIn"] as? Bool ?? false,
                authMethod: json["authMethod"] as? String ?? "unknown",
                email: json["email"] as? String,
                orgName: json["orgName"] as? String,
                subscriptionType: json["subscriptionType"] as? String
            )
        } catch {
            return AuthStatus(loggedIn: false, authMethod: "error", email: nil, orgName: nil, subscriptionType: nil)
        }
    }

    func startOAuthLogin(email: String? = nil) {
        guard isAvailable else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        var args = ["auth", "login"]
        if let email { args.append(contentsOf: ["--email", email]) }
        process.arguments = args
        process.environment = cleanEnvironment()
        try? process.run()
    }

    func logout() {
        guard isAvailable else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = ["auth", "logout"]
        process.standardInput = FileHandle.nullDevice
        process.environment = cleanEnvironment()
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Team Agent Message (with session, tools, streaming)

    /// Send a message to an agent with full team capabilities
    /// - Parameters:
    ///   - prompt: User message
    ///   - agentName: Name of the agent (used for session persistence and --agent flag)
    ///   - systemPrompt: System prompt override
    ///   - tools: Allowed tools for this agent (e.g. ["Read", "Write", "Bash"])
    ///   - model: Model to use (e.g. "sonnet", "opus")
    ///   - onChunk: Streaming callback for each text chunk
    /// - Returns: Full response text
    func sendAgentMessage(
        prompt: String,
        agentName: String,
        systemPrompt: String?,
        tools: [String],
        model: String?,
        onChunk: @escaping (String) -> Void,
        onToolUse: @escaping (String?) -> Void = { _ in }
    ) async throws -> String {
        var args: [String] = ["-p", prompt]

        // Use stream-json for real-time output (requires --verbose)
        args.append(contentsOf: ["--output-format", "stream-json", "--verbose"])

        // Persistent session per agent
        let sessionId = agentSessions[agentName] ?? UUID().uuidString
        agentSessions[agentName] = sessionId

        // Use --continue if agent has an existing session
        if agentSessions[agentName] != nil {
            args.append(contentsOf: ["--session-id", sessionId])
        }

        // System prompt
        if let system = systemPrompt, !system.isEmpty {
            args.append(contentsOf: ["--system-prompt", system])
        }

        // Agent tools
        if !tools.isEmpty {
            args.append(contentsOf: ["--allowed-tools", tools.joined(separator: ",")])
        }

        // Model
        if let model, !model.isEmpty {
            args.append(contentsOf: ["--model", model])
        }

        // Permission mode: auto-approve tool use
        args.append(contentsOf: ["--permission-mode", "bypassPermissions"])

        return try await runClaudeStreaming(args: args, onChunk: onChunk, onToolUse: onToolUse)
    }

    // MARK: - Simple Message (legacy, no session)

    func sendMessage(prompt: String, systemPrompt: String?) async throws -> String {
        var args = ["-p", prompt, "--output-format", "text"]
        if let system = systemPrompt, !system.isEmpty {
            args.insert(contentsOf: ["--system-prompt", system], at: 0)
        }
        return try await runClaude(args: args)
    }

    // MARK: - Session Management

    func resetSession(for agentName: String) {
        agentSessions.removeValue(forKey: agentName)
    }

    func resetAllSessions() {
        agentSessions.removeAll()
    }

    // MARK: - Memory Search (claude-mem integration)

    func searchMemory(query: String) async throws -> String {
        let prompt = """
        Search my memory for: \(query)
        Use the mcp__plugin_claude-mem_mcp-search__search tool with query "\(query)" and return the results.
        List each result with: ID, title, type, and time.
        """
        return try await runClaude(args: ["-p", prompt, "--output-format", "text"])
    }

    func getMemoryDetail(ids: [Int]) async throws -> String {
        let idList = ids.map(String.init).joined(separator: ", ")
        let prompt = """
        Fetch full details for memory observations with IDs: [\(idList)]
        Use the mcp__plugin_claude-mem_mcp-search__get_observations tool and return the full content.
        """
        return try await runClaude(args: ["-p", prompt, "--output-format", "text"])
    }

    // MARK: - Run Process (blocking, text output)

    private func runClaude(args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: self.claudePath)
                process.arguments = args

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                process.standardInput = FileHandle.nullDevice
                process.environment = self.cleanEnvironment()

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""

                    if process.terminationStatus == 0 {
                        continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                    } else {
                        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                        let errStr = String(data: errData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(
                            throwing: CLIError.executionFailed("exit \(process.terminationStatus): \(errStr)")
                        )
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Run Process (streaming, stream-json output)

    private func runClaudeStreaming(
        args: [String],
        onChunk: @escaping (String) -> Void,
        onToolUse: @escaping (String?) -> Void
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: self.claudePath)
                process.arguments = args

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                process.standardInput = FileHandle.nullDevice
                process.environment = self.cleanEnvironment()

                var fullResponse = ""
                var buffer = Data()

                // Read output incrementally
                outPipe.fileHandleForReading.readabilityHandler = { handle in
                    let newData = handle.availableData
                    guard !newData.isEmpty else { return }

                    buffer.append(newData)

                    // Process complete JSON lines
                    while let newlineRange = buffer.range(of: Data("\n".utf8)) {
                        let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
                        buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)

                        guard let line = String(data: lineData, encoding: .utf8),
                              !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

                        // Parse stream-json events
                        if let json = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] {
                            let type = json["type"] as? String ?? ""

                            if type == "assistant" {
                                // Text content from assistant
                                if let message = json["message"] as? [String: Any],
                                   let content = message["content"] as? [[String: Any]] {
                                    for block in content {
                                        if block["type"] as? String == "text",
                                           let text = block["text"] as? String {
                                            let newText = String(text.dropFirst(fullResponse.count))
                                            if !newText.isEmpty {
                                                fullResponse = text
                                                DispatchQueue.main.async { onChunk(newText) }
                                            }
                                        }
                                    }
                                }
                            } else if type == "assistant" {
                                // Check for tool_use in content blocks
                                if let message = json["message"] as? [String: Any],
                                   let content = message["content"] as? [[String: Any]] {
                                    for block in content {
                                        if block["type"] as? String == "tool_use",
                                           let toolName = block["name"] as? String {
                                            DispatchQueue.main.async { onToolUse(toolName) }
                                        }
                                    }
                                }
                            } else if type == "result" {
                                // Final result - clear tool indicator
                                DispatchQueue.main.async { onToolUse(nil) }
                                if let result = json["result"] as? String, !result.isEmpty {
                                    let remaining = String(result.dropFirst(fullResponse.count))
                                    if !remaining.isEmpty {
                                        fullResponse = result
                                        DispatchQueue.main.async { onChunk(remaining) }
                                    }
                                }
                            }
                        }
                    }
                }

                do {
                    try process.run()
                    process.waitUntilExit()

                    // Clean up handler
                    outPipe.fileHandleForReading.readabilityHandler = nil

                    // Process any remaining buffer
                    let remainingData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    if !remainingData.isEmpty {
                        buffer.append(remainingData)
                    }

                    // Parse any final lines in buffer
                    if let finalStr = String(data: buffer, encoding: .utf8) {
                        for line in finalStr.components(separatedBy: "\n") where !line.isEmpty {
                            if let json = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                               let type = json["type"] as? String, type == "result",
                               let result = json["result"] as? String {
                                fullResponse = result
                            }
                        }
                    }

                    if process.terminationStatus == 0 {
                        continuation.resume(returning: fullResponse)
                    } else {
                        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                        let errStr = String(data: errData, encoding: .utf8) ?? "Unknown error"
                        if fullResponse.isEmpty {
                            continuation.resume(
                                throwing: CLIError.executionFailed("exit \(process.terminationStatus): \(errStr)")
                            )
                        } else {
                            // Got partial response before error
                            continuation.resume(returning: fullResponse)
                        }
                    }
                } catch {
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Find Claude

    private static func findClaudePath() -> String? {
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/claude",
            "\(NSHomeDirectory())/.claude/local/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(NSHomeDirectory())/.npm-global/bin/claude",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        return nil
    }

    enum CLIError: LocalizedError {
        case executionFailed(String)

        var errorDescription: String? {
            switch self {
            case .executionFailed(let msg): return "Claude CLI error: \(msg)"
            }
        }
    }
}
