import Testing
import Foundation
@testable import AgentDock

@Suite("KeychainService")
struct KeychainServiceTests {

    // Unique keys per test to avoid cross-test interference
    private static let baseKey = "agentdock-test"

    private func uniqueKey(_ suffix: String = "") -> String {
        "\(Self.baseKey)-\(UUID().uuidString)\(suffix.isEmpty ? "" : "-\(suffix)")"
    }

    // MARK: - save Tests

    @Test("save returns true on first save")
    func save_returnsTrueOnSuccess() {
        let key = uniqueKey("save")
        defer { KeychainService.delete(key: key) }
        let result = KeychainService.save(key: key, value: "hello")
        #expect(result)
    }

    @Test("save with empty string value returns true")
    func save_emptyValue_returnsTrue() {
        let key = uniqueKey("empty")
        defer { KeychainService.delete(key: key) }
        let result = KeychainService.save(key: key, value: "")
        #expect(result)
    }

    @Test("save overwrites existing key and returns true")
    func save_overwriteExistingKey_returnsTrue() {
        let key = uniqueKey("overwrite")
        defer { KeychainService.delete(key: key) }
        KeychainService.save(key: key, value: "first")
        let result = KeychainService.save(key: key, value: "second")
        #expect(result)
    }

    @Test("save with special characters returns true")
    func save_specialCharacters_succeeds() {
        let key = uniqueKey("special")
        defer { KeychainService.delete(key: key) }
        let result = KeychainService.save(key: key, value: "p@$$w0rd!#%&*()")
        #expect(result)
    }

    @Test("save with 4096 character value returns true")
    func save_longValue_succeeds() {
        let key = uniqueKey("long")
        defer { KeychainService.delete(key: key) }
        let result = KeychainService.save(key: key, value: String(repeating: "a", count: 4096))
        #expect(result)
    }

    // MARK: - load Tests

    @Test("load after save returns the saved value")
    func load_afterSave_returnsValue() {
        let key = uniqueKey("load")
        defer { KeychainService.delete(key: key) }
        KeychainService.save(key: key, value: "test-value")
        #expect(KeychainService.load(key: key) == "test-value")
    }

    @Test("load for non-existent key returns nil")
    func load_nonExistentKey_returnsNil() {
        let key = "agentdock-nonexistent-\(UUID().uuidString)"
        #expect(KeychainService.load(key: key) == nil)
    }

    @Test("load after overwrite returns the latest value")
    func load_afterOverwrite_returnsLatest() {
        let key = uniqueKey("latest")
        defer { KeychainService.delete(key: key) }
        KeychainService.save(key: key, value: "original")
        KeychainService.save(key: key, value: "updated")
        #expect(KeychainService.load(key: key) == "updated")
    }

    @Test("empty string round-trips through save and load")
    func load_emptyString_roundTrips() {
        let key = uniqueKey("emptyload")
        defer { KeychainService.delete(key: key) }
        KeychainService.save(key: key, value: "")
        #expect(KeychainService.load(key: key) == "")
    }

    @Test("special characters round-trip through save and load")
    func load_specialCharacters_roundTrips() {
        let key = uniqueKey("specialload")
        defer { KeychainService.delete(key: key) }
        let special = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
        KeychainService.save(key: key, value: special)
        #expect(KeychainService.load(key: key) == special)
    }

    @Test("Unicode value round-trips through save and load")
    func load_unicodeValue_roundTrips() {
        let key = uniqueKey("unicode")
        defer { KeychainService.delete(key: key) }
        let unicode = "안녕하세요 🎉 こんにちは"
        KeychainService.save(key: key, value: unicode)
        #expect(KeychainService.load(key: key) == unicode)
    }

    @Test("Multiline value round-trips through save and load")
    func load_multilineValue_roundTrips() {
        let key = uniqueKey("multiline")
        defer { KeychainService.delete(key: key) }
        let multiline = "line1\nline2\nline3"
        KeychainService.save(key: key, value: multiline)
        #expect(KeychainService.load(key: key) == multiline)
    }

    // MARK: - delete Tests

    @Test("delete existing key returns true")
    func delete_existingKey_returnsTrue() {
        let key = uniqueKey("del")
        KeychainService.save(key: key, value: "value")
        let result = KeychainService.delete(key: key)
        #expect(result)
    }

    @Test("delete non-existent key returns true (errSecItemNotFound treated as success)")
    func delete_nonExistentKey_returnsTrue() {
        let key = "agentdock-nonexistent-\(UUID().uuidString)"
        #expect(KeychainService.delete(key: key))
    }

    @Test("load returns nil after delete")
    func delete_afterDelete_loadReturnsNil() {
        let key = uniqueKey("afterdel")
        KeychainService.save(key: key, value: "value")
        KeychainService.delete(key: key)
        #expect(KeychainService.load(key: key) == nil)
    }

    @Test("double delete does not crash and returns true")
    func delete_twice_doesNotCrash() {
        let key = uniqueKey("double")
        KeychainService.save(key: key, value: "value")
        KeychainService.delete(key: key)
        #expect(KeychainService.delete(key: key))
    }

    // MARK: - Integration Tests

    @Test("full save/load/delete cycle works correctly")
    func integration_fullCycle() {
        let key = uniqueKey("cycle")
        let value = "full-cycle-test-value"

        let saved = KeychainService.save(key: key, value: value)
        #expect(saved)

        #expect(KeychainService.load(key: key) == value)

        let deleted = KeychainService.delete(key: key)
        #expect(deleted)

        #expect(KeychainService.load(key: key) == nil)
    }

    @Test("multiple keys are stored and retrieved independently")
    func integration_multipleKeys_areIndependent() {
        let key1 = uniqueKey("k1")
        let key2 = uniqueKey("k2")
        defer {
            KeychainService.delete(key: key1)
            KeychainService.delete(key: key2)
        }

        KeychainService.save(key: key1, value: "value1")
        KeychainService.save(key: key2, value: "value2")

        #expect(KeychainService.load(key: key1) == "value1")
        #expect(KeychainService.load(key: key2) == "value2")

        KeychainService.delete(key: key1)
        #expect(KeychainService.load(key: key1) == nil)
        #expect(KeychainService.load(key: key2) == "value2")
    }
}
