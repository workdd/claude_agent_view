import AppKit

/// Loads character PNG images from ~/.agentdock/characters/
/// Naming convention: {character}_{status}.png (e.g. bear_idle.png, pig_working.png)
class CharacterImageService {
    static let shared = CharacterImageService()

    private let characterDir: URL
    private var imageCache: [String: NSImage] = [:]
    private var missingKeys: Set<String> = []

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        characterDir = home.appendingPathComponent(".agentdock/characters")
        ensureDirectoryExists()
    }

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: characterDir,
            withIntermediateDirectories: true
        )
    }

    /// Load character image for a given character type and status
    func image(for character: String, status: AgentStatus) -> NSImage? {
        let key = "\(character)_\(status.rawValue)"

        // Fast path: already know this is missing
        if missingKeys.contains(key) && missingKeys.contains("\(character)_idle") {
            return nil
        }

        if let cached = imageCache[key] { return cached }

        // Try exact status image first
        let statusPath = characterDir.appendingPathComponent("\(key).png")
        if let image = NSImage(contentsOf: statusPath) {
            imageCache[key] = image
            return image
        }
        missingKeys.insert(key)

        // Fall back to idle image for any status
        let idleKey = "\(character)_idle"
        if let cached = imageCache[idleKey] { return cached }

        let idlePath = characterDir.appendingPathComponent("\(idleKey).png")
        if let image = NSImage(contentsOf: idlePath) {
            imageCache[idleKey] = image
            return image
        }
        missingKeys.insert(idleKey)

        return nil
    }

    /// Check if any images exist for a character
    func hasImages(for character: String) -> Bool {
        let path = characterDir.appendingPathComponent("\(character)_idle.png")
        return FileManager.default.fileExists(atPath: path.path)
    }

    /// Check if any character has images
    var hasAnyImages: Bool {
        for char in ["bear", "pig", "cat"] {
            if hasImages(for: char) { return true }
        }
        return false
    }

    /// Reload images (after user adds new ones)
    func clearCache() {
        imageCache.removeAll()
        missingKeys.removeAll()
    }

    /// Character directory path
    var directoryPath: String { characterDir.path }

    /// Open the character directory in Finder
    func openInFinder() {
        NSWorkspace.shared.open(characterDir)
    }
}
