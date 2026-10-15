import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = ClipboardMonitor.shared
        _ = PanelController.shared
        hotKey = HotKey { PanelController.shared.toggle() } // ⌘⇧V

        // Ask once for the Accessibility permission needed to auto-paste
        _ = Accessibility.isTrusted(prompt: true)
    }
}

@main
struct ClipVaultApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var monitor = ClipboardMonitor.shared

    var body: some Scene {
        MenuBarExtra("ClipVault", systemImage: "doc.on.clipboard") {
            Button("Show History  ⌘⇧V") { PanelController.shared.show() }
            Divider()
            if monitor.items.isEmpty {
                Text("Nothing copied yet")
            } else {
                ForEach(monitor.items.prefix(10)) { item in
                    Button(preview(item.text)) { monitor.copy(item) }
                }
                Divider()
                Button("Clear History") { monitor.clear() }
            }
            Divider()
            Button("Quit ClipVault") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    private func preview(_ text: String) -> String {
        let oneLine = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        return oneLine.count > 50 ? String(oneLine.prefix(50)) + "…" : oneLine
    }
}
