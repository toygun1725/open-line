import Foundation

struct AppPreferences: Codable {
    var activeStoryID: String
    var language: AppLanguage
    var fontStyle: AppFontStyle
    var replyFontStyle: ReplyFontStyle?
    var isMuted: Bool
    var isAllAccessUnlocked: Bool?
}

final class SaveStore {
    private let baseDir: URL
    private let prefsURL: URL

    init(directoryURL: URL? = nil, filename: String = "save_state.json") {
        let dir: URL
        if let directoryURL {
            dir = directoryURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            dir = appSupport.appendingPathComponent("AcikHat", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.baseDir = dir
        self.prefsURL = dir.appendingPathComponent("preferences.json")
        _ = filename
    }

    private func saveURL(for storyID: String) -> URL {
        let safeID = storyID.replacingOccurrences(of: "/", with: "_")
        return baseDir.appendingPathComponent("save_\(safeID).json")
    }

    func loadPreferences() -> AppPreferences? {
        guard FileManager.default.fileExists(atPath: prefsURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: prefsURL)
            return try JSONDecoder().decode(AppPreferences.self, from: data)
        } catch {
            return nil
        }
    }

    func savePreferences(_ prefs: AppPreferences) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(prefs)
            try data.write(to: prefsURL, options: [.atomic])
        } catch {
            // Preserve existing preferences if write fails.
        }
    }

    func load(storyID: String) -> PersistedSaveState? {
        let url = saveURL(for: storyID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(PersistedSaveState.self, from: data)
        } catch {
            return nil
        }
    }

    func save(_ state: PersistedSaveState, storyID: String) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(state)
            try data.write(to: saveURL(for: storyID), options: [.atomic])
        } catch {
            // Preserve existing save on disk if encoding fails.
        }
    }

    func clear(storyID: String) {
        try? FileManager.default.removeItem(at: saveURL(for: storyID))
    }
}
