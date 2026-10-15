import AppKit
import Combine

struct ClipItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let date: Date
    let sourceAppName: String?
    let sourceAppPath: String?
}

@MainActor
final class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    @Published private(set) var items: [ClipItem] = []

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let maxItems = 200

    private init() {
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            // Timers scheduled here fire on the main thread
            MainActor.assumeIsolated { self?.check() }
        }
    }

    private func check() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        // Skip passwords that password managers mark as hidden
        let types = pasteboard.types ?? []
        if types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) { return }

        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let app = NSWorkspace.shared.frontmostApplication
        items.removeAll { $0.text == text }
        items.insert(ClipItem(text: text,
                              date: Date(),
                              sourceAppName: app?.localizedName,
                              sourceAppPath: app?.bundleURL?.path),
                     at: 0)
        if items.count > maxItems { items.removeLast(items.count - maxItems) }
    }

    /// Puts the item on the clipboard and moves it to the front of the history.
    func copy(_ item: ClipItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
    }

    func clear() {
        items.removeAll()
    }
}
