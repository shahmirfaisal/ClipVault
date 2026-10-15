import AppKit
import SwiftUI
import Combine

/// A borderless panel that can take keyboard input without activating ClipVault,
/// so the app you were typing in stays frontmost and receives the paste.
final class PastePanel: NSPanel {
    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = PanelController()

    @Published var selectedIndex = 0
    @Published var query = ""
    @Published var showPinnedOnly = false

    let monitor = ClipboardMonitor.shared
    private let panel = PastePanel()
    private var keyMonitor: Any?
    private let panelHeight: CGFloat = 310

    var filteredItems: [ClipItem] {
        var list = monitor.items
        if showPinnedOnly { list = list.filter(\.isPinned) }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return list }
        return list.filter { $0.searchableText.localizedCaseInsensitiveContains(q) }
    }

    var selectedItem: ClipItem? {
        let items = filteredItems
        return items.indices.contains(selectedIndex) ? items[selectedIndex] : nil
    }

    private override init() {
        super.init()
        panel.delegate = self
        let root = HistoryView()
            .environmentObject(self)
            .environmentObject(monitor)
            .environmentObject(AppSettings.shared)
        panel.contentView = NSHostingView(rootView: root)
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        selectedIndex = 0
        query = ""

        // Use the screen the mouse is on
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        let target = NSRect(x: visible.minX, y: visible.minY, width: visible.width, height: panelHeight)
        var start = target
        start.origin.y -= panelHeight

        panel.setFrame(start, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }
        startKeyMonitor()
    }

    func hide() {
        stopKeyMonitor()
        guard panel.isVisible else { return }
        var end = panel.frame
        end.origin.y -= panelHeight
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().setFrame(end, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: { [panel] in
            panel.orderOut(nil)
        })
    }

    /// Copies the item, closes the panel, and pastes into the app you were using.
    func paste(_ item: ClipItem) {
        monitor.copy(item)
        hide()
        guard Accessibility.isTrusted(prompt: true) else { return } // falls back to "copied, press ⌘V yourself"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            Self.sendCommandV()
        }
    }

    /// Copies without pasting.
    func copyOnly(_ item: ClipItem) {
        monitor.copy(item)
        hide()
    }

    func togglePin(_ item: ClipItem) {
        monitor.togglePin(item)
        clampSelection()
    }

    func delete(_ item: ClipItem) {
        monitor.delete(item)
        clampSelection()
    }

    func togglePinnedFilter() {
        showPinnedOnly.toggle()
        selectedIndex = 0
    }

    func openSettings() {
        hide()
        SettingsWindowController.shared.show()
    }

    private func clampSelection() {
        selectedIndex = min(selectedIndex, max(filteredItems.count - 1, 0))
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // "V"
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    // MARK: Keyboard

    private func startKeyMonitor() {
        stopKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func stopKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Returns true if the key was handled here.
    private func handle(_ event: NSEvent) -> Bool {
        let count = filteredItems.count
        let command = event.modifierFlags.contains(.command)

        switch Int(event.keyCode) {
        case 53: // Esc
            if !query.isEmpty { query = ""; selectedIndex = 0 } else { hide() }
            return true
        case 36, 76: // Return / Enter
            if let item = selectedItem { paste(item) }
            return true
        case 123: // ←
            selectedIndex = max(0, selectedIndex - 1)
            return true
        case 124: // →
            selectedIndex = min(max(count - 1, 0), selectedIndex + 1)
            return true
        case 48: // Tab — switch between All and Pinned
            togglePinnedFilter()
            return true
        case 51 where command: // ⌘⌫ — delete
            if let item = selectedItem { delete(item) }
            return true
        default:
            break
        }

        if command, let chars = event.charactersIgnoringModifiers?.lowercased() {
            if chars == "p", let item = selectedItem { togglePin(item); return true }
            if chars == "c", let item = selectedItem { copyOnly(item); return true }
            if chars == "," { openSettings(); return true }
            // ⌘1…⌘9 pastes that card directly
            if let n = Int(chars), (1...9).contains(n) {
                let items = filteredItems
                if items.indices.contains(n - 1) { paste(items[n - 1]) }
                return true
            }
        }
        return false // let typing go to the search field
    }

    // Close when you click somewhere else
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}

enum Accessibility {
    static func isTrusted(prompt: Bool) -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
