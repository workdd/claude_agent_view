import Foundation
import SQLite3

/// Direct access to claude-mem SQLite database for reading memories
class MemoryService {
    private let dbPath: String
    private var db: OpaquePointer?

    init(dbPath: String? = nil) {
        self.dbPath = dbPath ?? "\(NSHomeDirectory())/.claude-mem/claude-mem.db"
    }

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: dbPath)
    }

    // MARK: - Open / Close

    private func open() -> Bool {
        guard db == nil else { return true }
        return sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK
    }

    private func close() {
        if let db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    // MARK: - Search Memories

    func searchMemories(query: String, limit: Int = 20) -> [MemoryItem] {
        guard open() else { return [] }
        defer { close() }

        let sql = """
            SELECT id, title, subtitle, type, project,
                   created_at, facts, narrative
            FROM observations
            WHERE title LIKE ? OR subtitle LIKE ? OR narrative LIKE ? OR facts LIKE ?
            ORDER BY created_at DESC
            LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        let pattern = "%\(query)%"
        sqlite3_bind_text(stmt, 1, pattern, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, pattern, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 3, pattern, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 4, pattern, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int(stmt, 5, Int32(limit))

        var items: [MemoryItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let item = MemoryItem(
                id: Int(sqlite3_column_int64(stmt, 0)),
                title: columnText(stmt, 1),
                subtitle: columnText(stmt, 2),
                type: columnText(stmt, 3),
                project: columnText(stmt, 4),
                createdAt: columnText(stmt, 5),
                facts: columnText(stmt, 6),
                narrative: columnText(stmt, 7)
            )
            items.append(item)
        }
        return items
    }

    func recentMemories(limit: Int = 30) -> [MemoryItem] {
        guard open() else { return [] }
        defer { close() }

        let sql = """
            SELECT id, title, subtitle, type, project,
                   created_at, facts, narrative
            FROM observations
            ORDER BY created_at DESC
            LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(limit))

        var items: [MemoryItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let item = MemoryItem(
                id: Int(sqlite3_column_int64(stmt, 0)),
                title: columnText(stmt, 1),
                subtitle: columnText(stmt, 2),
                type: columnText(stmt, 3),
                project: columnText(stmt, 4),
                createdAt: columnText(stmt, 5),
                facts: columnText(stmt, 6),
                narrative: columnText(stmt, 7)
            )
            items.append(item)
        }
        return items
    }

    func getMemory(id: Int) -> MemoryItem? {
        guard open() else { return nil }
        defer { close() }

        let sql = """
            SELECT id, title, subtitle, type, project,
                   created_at, facts, narrative
            FROM observations WHERE id = ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, Int64(id))

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        return MemoryItem(
            id: Int(sqlite3_column_int64(stmt, 0)),
            title: columnText(stmt, 1),
            subtitle: columnText(stmt, 2),
            type: columnText(stmt, 3),
            project: columnText(stmt, 4),
            createdAt: columnText(stmt, 5),
            facts: columnText(stmt, 6),
            narrative: columnText(stmt, 7)
        )
    }

    func memoryStats() -> (total: Int, projects: [String]) {
        guard open() else { return (0, []) }
        defer { close() }

        var total = 0
        var projects: [String] = []

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM observations", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                total = Int(sqlite3_column_int64(stmt, 0))
            }
            sqlite3_finalize(stmt)
        }

        if sqlite3_prepare_v2(db, "SELECT DISTINCT project FROM observations WHERE project IS NOT NULL", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                projects.append(columnText(stmt, 0))
            }
            sqlite3_finalize(stmt)
        }

        return (total, projects)
    }

    private func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String {
        guard let cStr = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: cStr)
    }
}

// MARK: - Memory Model

struct MemoryItem: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let type: String       // discovery, feature, bugfix, decision, change
    let project: String
    let createdAt: String
    let facts: String
    let narrative: String

    var typeIcon: String {
        switch type {
        case "discovery": return "magnifyingglass"
        case "feature": return "star.fill"
        case "bugfix": return "ladybug.fill"
        case "decision": return "scalemass.fill"
        case "change": return "checkmark.circle.fill"
        default: return "doc.text"
        }
    }

    var typeLabel: String {
        switch type {
        case "discovery": return "Discovery"
        case "feature": return "Feature"
        case "bugfix": return "Bugfix"
        case "decision": return "Decision"
        case "change": return "Change"
        default: return type.capitalized
        }
    }
}
