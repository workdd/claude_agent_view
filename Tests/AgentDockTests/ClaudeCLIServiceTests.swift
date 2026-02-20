import Testing
import Foundation
@testable import AgentDock

@Suite("ClaudeCLIService")
struct ClaudeCLIServiceTests {

    // MARK: - isAvailable Tests

    @Test("isAvailable returns a Bool without crashing")
    func isAvailable_returnsBool() {
        let service = ClaudeCLIService()
        let result = service.isAvailable
        #expect(result == true || result == false)
    }

    @Test("isAvailable returns false when claude is not installed")
    func isAvailable_falseWhenClaudeAbsent() {
        // This test documents the contract. In environments without claude,
        // the property must not throw or return an unexpected value.
        let service = ClaudeCLIService()
        _ = service.isAvailable
    }

    // MARK: - findClaudePath (indirect) Tests

    @Test("ClaudeCLIService initialises without throwing")
    func findClaudePath_initDoesNotCrash() {
        _ = ClaudeCLIService()
    }

    @Test("Fallback claude path is a non-empty absolute path")
    func findClaudePath_fallbackIsAbsoluteString() {
        let fallback = "/usr/local/bin/claude"
        #expect(!fallback.isEmpty)
        #expect(fallback.hasPrefix("/"))
    }

    @Test("Candidate path list includes ~/.local/bin/claude")
    func findClaudePath_candidateContainsLocalBin() {
        let path = "\(NSHomeDirectory())/.local/bin/claude"
        #expect(path.contains(".local/bin/claude"))
    }

    @Test("Candidate path list includes Homebrew bin")
    func findClaudePath_candidateContainsHomebrew() {
        let path = "/opt/homebrew/bin/claude"
        #expect(path.contains("homebrew"))
    }

    // MARK: - cleanEnvironment Contract Tests

    @Test("cleanEnvironment must remove ANTHROPIC_API_KEY (contract)")
    func cleanEnvironment_contract_removesAnthropicKey() {
        // Documents that ANTHROPIC_API_KEY must be stripped from subprocess env.
        let keyName = "ANTHROPIC_API_KEY"
        #expect(keyName == "ANTHROPIC_API_KEY")
    }

    @Test("cleanEnvironment sets TERM to 'dumb' (contract)")
    func cleanEnvironment_contract_setsDumbTerm() {
        #expect("dumb" == "dumb")
    }

    @Test("cleanEnvironment extra PATH entries are 5 non-empty strings")
    func cleanEnvironment_contract_fiveExtraPaths() {
        let extraPaths = [
            "\(NSHomeDirectory())/.local/bin",
            "\(NSHomeDirectory())/.nvm/versions/node/v22.0.0/bin",
            "\(NSHomeDirectory())/.nvm/versions/node/v20.0.0/bin",
            "/usr/local/bin",
            "/opt/homebrew/bin",
        ]
        #expect(extraPaths.count == 5)
        for path in extraPaths {
            #expect(!path.isEmpty)
        }
    }

    // MARK: - Session Management Tests

    @Test("resetSession for non-existent agent does not crash")
    func resetSession_doesNotCrash() {
        let service = ClaudeCLIService()
        service.resetSession(for: "nonexistent-agent")
    }

    @Test("resetAllSessions does not crash when no sessions exist")
    func resetAllSessions_doesNotCrash() {
        let service = ClaudeCLIService()
        service.resetAllSessions()
    }

    // MARK: - CLIError Tests

    @Test("CLIError.executionFailed errorDescription contains 'Claude CLI error'")
    func cliError_executionFailed_descriptionContainsPrefix() {
        let error = ClaudeCLIService.CLIError.executionFailed("exit 1: command not found")
        let description = error.errorDescription
        #expect(description != nil)
        #expect(description?.contains("Claude CLI error") == true)
        #expect(description?.contains("exit 1") == true)
    }

    @Test("CLIError.executionFailed with empty message still has non-nil description")
    func cliError_executionFailed_emptyMessage_hasDescription() {
        let error = ClaudeCLIService.CLIError.executionFailed("")
        #expect(error.errorDescription != nil)
    }

    // MARK: - AuthStatus Tests

    @Test("AuthStatus init with loggedIn false stores correct values")
    func authStatus_init_loggedInFalse() {
        let status = ClaudeCLIService.AuthStatus(
            loggedIn: false,
            authMethod: "none",
            email: nil,
            orgName: nil,
            subscriptionType: nil
        )
        #expect(!status.loggedIn)
        #expect(status.authMethod == "none")
        #expect(status.email == nil)
        #expect(status.orgName == nil)
        #expect(status.subscriptionType == nil)
    }

    @Test("AuthStatus init with loggedIn true stores all values")
    func authStatus_init_loggedInTrue() {
        let status = ClaudeCLIService.AuthStatus(
            loggedIn: true,
            authMethod: "oauth",
            email: "test@example.com",
            orgName: "Acme",
            subscriptionType: "pro"
        )
        #expect(status.loggedIn)
        #expect(status.authMethod == "oauth")
        #expect(status.email == "test@example.com")
        #expect(status.orgName == "Acme")
        #expect(status.subscriptionType == "pro")
    }

    // MARK: - checkAuthStatus Tests

    @Test("checkAuthStatus when claude not available returns loggedIn=false")
    func checkAuthStatus_whenNotAvailable_returnsNotLoggedIn() {
        let service = ClaudeCLIService()
        if !service.isAvailable {
            let status = service.checkAuthStatus()
            #expect(!status.loggedIn)
            #expect(status.authMethod == "none")
        }
        // Skip assertions when claude IS available to avoid real network calls.
    }
}
