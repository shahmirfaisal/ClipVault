import Foundation

/// Saves history to ~/Library/Application Support/ClipVault/
enum HistoryStore {
    static let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("ClipVault", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let imagesFolder: URL = {
        let url = folder.appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static var historyFile: URL { folder.appendingPathComponent("history.json") }

    static func load() -> [ClipItem] {
        guard let data = try? Data(contentsOf: historyFile) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ClipItem].self, from: data)) ?? []
    }

    static func save(_ items: [ClipItem]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: historyFile, options: [.atomic])
        removeUnusedImages(keeping: items)
    }

    static func imageURL(_ name: String) -> URL {
        imagesFolder.appendingPathComponent(name)
    }

    /// Deletes image files that no longer belong to any history item.
    private static func removeUnusedImages(keeping items: [ClipItem]) {
        let used = Set(items.compactMap(\.imageFile))
        let files = (try? FileManager.default.contentsOfDirectory(atPath: imagesFolder.path)) ?? []
        for file in files where !used.contains(file) {
            try? FileManager.default.removeItem(at: imageURL(file))
        }
    }
}
