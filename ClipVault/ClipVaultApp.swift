import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = ClipboardMonitor.shared
        _ = PanelController.shared
        HotKeyCenter.shared.start { PanelController.shared.toggle() }

        // Ask once for the Accessibility permission needed to auto-paste
        _ = Accessibility.isTrusted(prompt: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClipboardMonitor.shared.saveNow()
    }
}

@main
struct ClipVaultApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var monitor = ClipboardMonitor.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        MenuBarExtra("ClipVault", systemImage: "doc.on.clipboard") {
            Button("Show History  \(settings.hotKeyDisplay)") { PanelController.shared.show() }
            Button("Settings…") { SettingsWindowController.shared.show() }
                .keyboardShortcut(",")
            Divider()
            if monitor.items.isEmpty {
                Text("Nothing copied yet")
            } else {
                ForEach(monitor.items.prefix(10)) { item in
                    Button((item.isPinned ? "📌 " : "") + item.menuTitle) { monitor.copy(item) }
                }
                Divider()
                Button("Clear History") { monitor.clear() }
            }
            Divider()
            Button("Quit ClipVault") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
