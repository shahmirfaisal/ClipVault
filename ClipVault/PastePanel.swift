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

    let monitor = ClipboardMonitor.shared
    private let panel = PastePanel()
    private var keyMonitor: Any?
    private let panelHeight: CGFloat = 300

    var filteredItems: [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return monitor.items }
        return monitor.items.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    private override init() {
        super.init()
        panel.delegate = self
        let root = HistoryView()
            .environmentObject(self)
            .environmentObject(monitor)
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

    func pasteSelected() {
        let items = filteredItems
        guard items.indices.contains(selectedIndex) else { return }
        paste(items[selectedIndex])
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
            guard let self else { return event }
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
        switch Int(event.keyCode) {
        case 53: // Esc
            if !query.isEmpty { query = ""; selectedIndex = 0 } else { hide() }
            return true
        case 36, 76: // Return / Enter
            pasteSelected()
            return true
        case 123: // ←
            selectedIndex = max(0, selectedIndex - 1)
            return true
        case 124: // →
            selectedIndex = min(max(count - 1, 0), selectedIndex + 1)
            return true
        default:
            break
        }

        // ⌘1…⌘9 pastes that card directly
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers, let n = Int(chars), (1...9).contains(n) {
            let items = filteredItems
            if items.indices.contains(n - 1) { paste(items[n - 1]) }
            return true
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
}
