import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView()
                .environmentObject(AppSettings.shared)
                .environmentObject(ClipboardMonitor.shared))
            let w = NSWindow(contentViewController: hosting)
            w.title = "ClipVault Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var monitor: ClipboardMonitor
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var accessibilityOK = Accessibility.isTrusted(prompt: false)
    @State private var selectedApp: String?

    private let limits = [50, 100, 200, 500, 1000]

    var body: some View {
        Form {
            Section("General") {
                LabeledContent("Open ClipVault") {
                    ShortcutRecorder()
                }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }

            Section("History") {
                Picker("Keep the last", selection: $settings.historyLimit) {
                    ForEach(limits, id: \.self) { Text("\($0) items").tag($0) }
                }
                Text("Pinned items are always kept and don't count toward this limit.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Clear History…") { confirmClear() }
                    Button("Show Data Folder") {
                        NSWorkspace.shared.activateFileViewerSelecting([HistoryStore.folder])
                    }
                }
            }

            Section("Ignore copies from these apps") {
                List(selection: $selectedApp) {
                    ForEach(settings.excludedApps, id: \.self) { id in
                        AppRow(bundleID: id).tag(id)
                    }
                }
                .frame(height: 120)
                HStack {
                    Button { addExcludedApp() } label: { Image(systemName: "plus") }
                    Button {
                        if let selectedApp { settings.excludedApps.removeAll { $0 == selectedApp } }
                        selectedApp = nil
                    } label: { Image(systemName: "minus") }
                    .disabled(selectedApp == nil)
                    Spacer()
                    Text("Passwords from password managers are always ignored.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Permissions") {
                HStack {
                    Image(systemName: accessibilityOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(accessibilityOK ? .green : .orange)
                    Text(accessibilityOK
                         ? "Accessibility is on — auto-paste works."
                         : "Accessibility is off — items are copied but not pasted automatically.")
                    Spacer()
                    if !accessibilityOK {
                        Button("Open Settings") { Accessibility.openSettings() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityOK = Accessibility.isTrusted(prompt: false)
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't change this: \(error.localizedDescription)"
        }
    }

    private func confirmClear() {
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "Pinned items will be kept."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { monitor.clear() }
    }

    private func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = "Ignore"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier, !settings.excludedApps.contains(id) {
                settings.excludedApps.append(id)
            }
        }
    }
}

struct AppRow: View {
    let bundleID: String

    var body: some View {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        HStack(spacing: 8) {
            if let url {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable().frame(width: 18, height: 18)
            }
            Text(url.map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID)
        }
    }
}

/// Click, then press a new key combination.
struct ShortcutRecorder: View {
    @EnvironmentObject var settings: AppSettings
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button(recording ? "Press shortcut…" : settings.hotKeyDisplay) {
            recording ? stop() : start()
        }
        .frame(minWidth: 120)
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        HotKeyCenter.shared.pause()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil } // Esc cancels
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            // Require ⌘, ⌥ or ⌃ so normal typing isn't hijacked
            guard !flags.intersection([.command, .option, .control]).isEmpty else { return nil }
            settings.hotKeyCode = Int(event.keyCode)
            settings.hotKeyModifiers = HotKeyCenter.carbonModifiers(from: flags)
            settings.hotKeyDisplay = HotKeyCenter.displayString(for: event)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        HotKeyCenter.shared.resume()
    }
}
