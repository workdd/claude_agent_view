import Testing
import Foundation
@testable import AgentDock

@Suite("ChatMessage Model")
struct ChatMessageTests {

    // MARK: - Initialization Tests

    @Test("init default id is non-nil UUID")
    func init_defaultId_isNonNil() {
        let message = ChatMessage(role: .user, content: "Hello")
        _ = message.id  // must compile and not crash
    }

    @Test("init with custom UUID preserves it")
    func init_customId_preserved() {
        let fixedId = UUID()
        let message = ChatMessage(id: fixedId, role: .user, content: "Test")
        #expect(message.id == fixedId)
    }

    @Test("init user role is stored correctly")
    func init_userRole() {
        let message = ChatMessage(role: .user, content: "User says hi")
        #expect(message.role == .user)
    }

    @Test("init assistant role is stored correctly")
    func init_assistantRole() {
        let message = ChatMessage(role: .assistant, content: "Assistant replies")
        #expect(message.role == .assistant)
    }

    @Test("init content is preserved verbatim")
    func init_contentPreserved() {
        let content = "Hello, this is a test message with special chars: !@#$%"
        let message = ChatMessage(role: .user, content: content)
        #expect(message.content == content)
    }

    @Test("init empty content is stored as empty string")
    func init_emptyContent() {
        let message = ChatMessage(role: .user, content: "")
        #expect(message.content == "")
    }

    @Test("init default timestamp is approximately now")
    func init_defaultTimestamp_isRecent() {
        let before = Date()
        let message = ChatMessage(role: .user, content: "Test")
        let after = Date()
        #expect(message.timestamp >= before)
        #expect(message.timestamp <= after)
    }

    @Test("init with custom timestamp preserves it")
    func init_customTimestamp_preserved() {
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        let message = ChatMessage(role: .user, content: "Test", timestamp: fixedDate)
        #expect(message.timestamp == fixedDate)
    }

    @Test("two messages with same content have different IDs")
    func uniqueIds_acrossInstances() {
        let m1 = ChatMessage(role: .user, content: "Same content")
        let m2 = ChatMessage(role: .user, content: "Same content")
        #expect(m1.id != m2.id)
    }

    // MARK: - MessageRole Tests

    @Test("MessageRole.user raw value is 'user'")
    func messageRole_rawValue_user() {
        #expect(MessageRole.user.rawValue == "user")
    }

    @Test("MessageRole.assistant raw value is 'assistant'")
    func messageRole_rawValue_assistant() {
        #expect(MessageRole.assistant.rawValue == "assistant")
    }

    @Test("MessageRole.user is decodable from JSON string 'user'")
    func messageRole_decodable_user() throws {
        let json = #"{"role":"user"}"#
        struct Wrapper: Decodable { let role: MessageRole }
        let decoded = try JSONDecoder().decode(Wrapper.self, from: Data(json.utf8))
        #expect(decoded.role == .user)
    }

    @Test("MessageRole.assistant is decodable from JSON string 'assistant'")
    func messageRole_decodable_assistant() throws {
        let json = #"{"role":"assistant"}"#
        struct Wrapper: Decodable { let role: MessageRole }
        let decoded = try JSONDecoder().decode(Wrapper.self, from: Data(json.utf8))
        #expect(decoded.role == .assistant)
    }

    // MARK: - Codable Round-Trip Tests

    @Test("ChatMessage encodes and decodes with correct fields")
    func chatMessage_roundTrip() throws {
        let original = ChatMessage(
            id: UUID(),
            role: .assistant,
            content: "Round trip content",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.role == original.role)
        #expect(decoded.content == original.content)
        // Date precision may vary; allow 1-second tolerance
        #expect(abs(decoded.timestamp.timeIntervalSince1970 - original.timestamp.timeIntervalSince1970) < 1.0)
    }

    @Test("Encoded JSON contains id, role, content, timestamp keys")
    func chatMessage_encodedJSON_containsExpectedKeys() throws {
        let message = ChatMessage(role: .user, content: "Test encoding")
        let encoded = try JSONEncoder().encode(message)
        let dict = try #require(try? JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        #expect(dict["id"] != nil)
        #expect(dict["role"] != nil)
        #expect(dict["content"] != nil)
        #expect(dict["timestamp"] != nil)
    }

    @Test("Encoded JSON role field is a string")
    func chatMessage_encodedJSON_roleIsString() throws {
        let message = ChatMessage(role: .user, content: "Role encoding test")
        let encoded = try JSONEncoder().encode(message)
        let dict = try #require(try? JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let roleValue = try #require(dict["role"] as? String)
        #expect(roleValue == "user")
    }

    @Test("Array of ChatMessages round-trips correctly")
    func chatMessage_array_roundTrip() throws {
        let messages: [ChatMessage] = [
            ChatMessage(role: .user, content: "First"),
            ChatMessage(role: .assistant, content: "Second"),
        ]

        let encoded = try JSONEncoder().encode(messages)
        let decoded = try JSONDecoder().decode([ChatMessage].self, from: encoded)

        #expect(decoded.count == 2)
        #expect(decoded[0].content == "First")
        #expect(decoded[1].role == .assistant)
    }

    @Test("Multiline content is preserved through encode/decode cycle")
    func chatMessage_multilineContent_preserved() throws {
        let multiline = "Line 1\nLine 2\nLine 3"
        let message = ChatMessage(role: .assistant, content: multiline)
        let encoded = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: encoded)
        #expect(decoded.content == multiline)
    }
}
