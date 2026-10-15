import Foundation

enum ClipKind: String, Codable {
    case text, link, image, file
}

struct ClipItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: ClipKind
    var date = Date()

    /// Text content, or the URL string for links.
    var text: String?
    /// File paths for copied files.
    var filePaths: [String]?
    /// PNG file name inside the images folder, for images.
    var imageFile: String?
    var imageWidth: Int?
    var imageHeight: Int?

    /// Used to avoid saving duplicates.
    var contentKey: String

    var sourceAppName: String?
    var sourceAppBundleID: String?
    var sourceAppPath: String?

    var isPinned = false

    /// Text used for search.
    var searchableText: String {
        var parts: [String] = []
        if let text { parts.append(text) }
        if let filePaths { parts += filePaths.map { ($0 as NSString).lastPathComponent } }
        if let sourceAppName { parts.append(sourceAppName) }
        if kind == .image { parts.append("image") }
        return parts.joined(separator: " ")
    }

    /// Short one-line description for the menu bar list.
    var menuTitle: String {
        switch kind {
        case .text, .link:
            let oneLine = (text ?? "")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
            return oneLine.count > 50 ? String(oneLine.prefix(50)) + "…" : oneLine
        case .image:
            if let w = imageWidth, let h = imageHeight { return "Image \(w)×\(h)" }
            return "Image"
        case .file:
            let names = (filePaths ?? []).map { ($0 as NSString).lastPathComponent }
            if names.count == 1 { return names[0] }
            return "\(names.count) files"
        }
    }
}
