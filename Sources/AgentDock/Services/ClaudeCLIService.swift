import Foundation

/// Uses the locally installed `claude` CLI (authenticated via Claude subscription)
/// instead of requiring a separate API key.
class ClaudeCLIService {

    private let claudePath: String

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

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "dumb"
        process.environment = env

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

    /// Opens the browser for Claude OAuth login
    func startOAuthLogin(email: String? = nil) {
        guard isAvailable else { return }

        // Run `claude auth login` which opens the browser for OAuth
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        var args = ["auth", "login"]
        if let email {
            args.append(contentsOf: ["--email", email])
        }
        process.arguments = args

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "dumb"
        process.environment = env

        try? process.run()
    }

    func logout() {
        guard isAvailable else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = ["auth", "logout"]
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "dumb"
        process.environment = env
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Send Message

    func sendMessage(prompt: String, systemPrompt: String?) async throws -> String {
        var args = ["-p", prompt, "--output-format", "text"]

        if let system = systemPrompt, !system.isEmpty {
            args.insert(contentsOf: ["--system-prompt", system], at: 0)
        }

        return try await runClaude(args: args)
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

    // MARK: - Run Process

    private func runClaude(args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: claudePath)
            process.arguments = args

            let pipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errorPipe

            var env = ProcessInfo.processInfo.environment
            env["TERM"] = "dumb"
            process.environment = env

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errStr = String(data: errData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: CLIError.executionFailed(errStr))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Find Claude

    private static func findClaudePath() -> String? {
        let candidates = [
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

        // Try `which claude`
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
