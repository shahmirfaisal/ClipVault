import Foundation
import Combine
import Carbon.HIToolbox

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    /// Max number of unpinned items to keep.
    @Published var historyLimit: Int {
        didSet { defaults.set(historyLimit, forKey: "historyLimit") }
    }

    /// Bundle IDs of apps whose copies are ignored.
    @Published var excludedApps: [String] {
        didSet { defaults.set(excludedApps, forKey: "excludedApps") }
    }

    // Global shortcut (Carbon key code + modifiers)
    @Published var hotKeyCode: Int {
        didSet { defaults.set(hotKeyCode, forKey: "hotKeyCode") }
    }
    @Published var hotKeyModifiers: Int {
        didSet { defaults.set(hotKeyModifiers, forKey: "hotKeyModifiers") }
    }
    @Published var hotKeyDisplay: String {
        didSet { defaults.set(hotKeyDisplay, forKey: "hotKeyDisplay") }
    }

    private init() {
        defaults.register(defaults: [
            "historyLimit": 200,
            "excludedApps": ["com.apple.keychainaccess"],
            "hotKeyCode": kVK_ANSI_V,
            "hotKeyModifiers": cmdKey | shiftKey,
            "hotKeyDisplay": "⇧⌘V",
        ])
        historyLimit = defaults.integer(forKey: "historyLimit")
        excludedApps = defaults.stringArray(forKey: "excludedApps") ?? []
        hotKeyCode = defaults.integer(forKey: "hotKeyCode")
        hotKeyModifiers = defaults.integer(forKey: "hotKeyModifiers")
        hotKeyDisplay = defaults.string(forKey: "hotKeyDisplay") ?? "⇧⌘V"
    }
}
