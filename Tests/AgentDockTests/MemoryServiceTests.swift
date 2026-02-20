import Testing
import Foundation
@testable import AgentDock

@Suite("MemoryService")
struct MemoryServiceTests {

    // MARK: - isAvailable Tests

    @Test("isAvailable returns false for non-existent db path")
    func isAvailable_nonExistentPath_returnsFalse() {
        let fakePath = "/tmp/does-not-exist-\(UUID().uuidString).db"
        let service = MemoryService(dbPath: fakePath)
        #expect(!service.isAvailable)
    }

    @Test("isAvailable returns true when db file exists")
    func isAvailable_withExistingFile_returnsTrue() throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let dbPath = tmpDir.appendingPathComponent("test-\(UUID().uuidString).db").path
        FileManager.default.createFile(atPath: dbPath, contents: Data())
        defer { try? FileManager.default.removeItem(atPath: dbPath) }

        let service = MemoryService(dbPath: dbPath)
        #expect(service.isAvailable)
    }

    @Test("isAvailable default init does not crash")
    func isAvailable_defaultPath_doesNotCrash() {
        let service = MemoryService()
        _ = service.isAvailable
    }

    // MARK: - memoryStats Tests

    @Test("memoryStats returns 0 total when db is unavailable")
    func memoryStats_unavailableDb_zeroTotal() {
        let service = MemoryService(dbPath: "/tmp/no-db-\(UUID().uuidString).db")
        let stats = service.memoryStats()
        #expect(stats.total == 0)
    }

    @Test("memoryStats returns empty projects when db is unavailable")
    func memoryStats_unavailableDb_emptyProjects() {
        let service = MemoryService(dbPath: "/tmp/no-db-\(UUID().uuidString).db")
        let stats = service.memoryStats()
        #expect(stats.projects.isEmpty)
    }

    @Test("memoryStats return type has expected shape")
    func memoryStats_returnType_hasExpectedShape() {
        let service = MemoryService(dbPath: "/tmp/no-db-\(UUID().uuidString).db")
        let stats = service.memoryStats()
        let total: Int = stats.total
        let projects: [String] = stats.projects
        #expect(total >= 0)
        #expect(projects.isEmpty || !projects.isEmpty)  // compile-time type check
    }

    // MARK: - searchMemories Tests

    @Test("searchMemories returns empty array when db is unavailable")
    func searchMemories_unavailableDb_returnsEmpty() {
        let service = MemoryService(dbPath: "/tmp/no-db-\(UUID().uuidString).db")
        let results = service.searchMemories(query: "anything")
        #expect(results.isEmpty)
    }

    @Test("searchMemories with empty query does not crash")
    func searchMemories_emptyQuery_doesNotCrash() {
        let service = MemoryService(dbPath: "/tmp/no-db-\(UUID().uuidString).db")
        let results = service.searchMemories(query: "")
        #expect(results.isEmpty)
    }

    @Test("searchMemories with custom limit does not crash")
    func searchMemories_customLimit_doesNotCrash() {
        let service = MemoryService(dbPath: "/tmp/no-db-\(UUID().uuidString).db")
        let results = service.searchMemories(query: "test", limit: 20)
        #expect(results.isEmpty)
    }

    // MARK: - recentMemories Tests

    @Test("recentMemories returns empty array when db is unavailable")
    func recentMemories_unavailableDb_returnsEmpty() {
        let service = MemoryService(dbPath: "/tmp/no-db-\(UUID().uuidString).db")
        let results = service.recentMemories(limit: 30)
        #expect(results.isEmpty)
    }

    // MARK: - getMemory Tests

    @Test("getMemory returns nil when db is unavailable")
    func getMemory_unavailableDb_returnsNil() {
        let service = MemoryService(dbPath: "/tmp/no-db-\(UUID().uuidString).db")
        let result = service.getMemory(id: 1)
        #expect(result == nil)
    }

    // MARK: - MemoryItem Model Tests

    @Test("MemoryItem typeIcon for discovery is 'magnifyingglass'")
    func memoryItem_typeIcon_discovery() {
        #expect(makeItem(type: "discovery").typeIcon == "magnifyingglass")
    }

    @Test("MemoryItem typeIcon for feature is 'star.fill'")
    func memoryItem_typeIcon_feature() {
        #expect(makeItem(type: "feature").typeIcon == "star.fill")
    }

    @Test("MemoryItem typeIcon for bugfix is 'ladybug.fill'")
    func memoryItem_typeIcon_bugfix() {
        #expect(makeItem(type: "bugfix").typeIcon == "ladybug.fill")
    }

    @Test("MemoryItem typeIcon for decision is 'scalemass.fill'")
    func memoryItem_typeIcon_decision() {
        #expect(makeItem(type: "decision").typeIcon == "scalemass.fill")
    }

    @Test("MemoryItem typeIcon for change is 'checkmark.circle.fill'")
    func memoryItem_typeIcon_change() {
        #expect(makeItem(type: "change").typeIcon == "checkmark.circle.fill")
    }

    @Test("MemoryItem typeIcon for unknown type is 'doc.text'")
    func memoryItem_typeIcon_unknown() {
        #expect(makeItem(type: "unknown_type").typeIcon == "doc.text")
    }

    @Test("MemoryItem typeLabel for discovery is 'Discovery'")
    func memoryItem_typeLabel_discovery() {
        #expect(makeItem(type: "discovery").typeLabel == "Discovery")
    }

    @Test("MemoryItem typeLabel for feature is 'Feature'")
    func memoryItem_typeLabel_feature() {
        #expect(makeItem(type: "feature").typeLabel == "Feature")
    }

    @Test("MemoryItem typeLabel for bugfix is 'Bugfix'")
    func memoryItem_typeLabel_bugfix() {
        #expect(makeItem(type: "bugfix").typeLabel == "Bugfix")
    }

    @Test("MemoryItem typeLabel for decision is 'Decision'")
    func memoryItem_typeLabel_decision() {
        #expect(makeItem(type: "decision").typeLabel == "Decision")
    }

    @Test("MemoryItem typeLabel for change is 'Change'")
    func memoryItem_typeLabel_change() {
        #expect(makeItem(type: "change").typeLabel == "Change")
    }

    @Test("MemoryItem typeLabel for unknown type is capitalized")
    func memoryItem_typeLabel_unknown_capitalized() {
        #expect(makeItem(type: "mytype").typeLabel == "Mytype")
    }

    @Test("MemoryItem id is correctly stored")
    func memoryItem_id_isSet() {
        let item = makeItem(id: 42, type: "feature")
        #expect(item.id == 42)
    }

    // MARK: - Helpers

    private func makeItem(id: Int = 1, type: String) -> MemoryItem {
        MemoryItem(
            id: id,
            title: "Test Title",
            subtitle: "Test Subtitle",
            type: type,
            project: "TestProject",
            createdAt: "2026-01-01",
            facts: "Some facts",
            narrative: "Some narrative"
        )
    }
}
