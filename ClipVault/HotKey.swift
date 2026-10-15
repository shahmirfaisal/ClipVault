import AppKit
import Carbon.HIToolbox

/// Registers a system-wide keyboard shortcut (works even when ClipVault isn't the active app).
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    nonisolated(unsafe) private static var action: (() -> Void)?

    /// Default: ⌘⇧V
    init(keyCode: Int = kVK_ANSI_V, modifiers: Int = cmdKey | shiftKey, action: @escaping () -> Void) {
        HotKey.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.action?() }
            return noErr
        }, 1, &eventType, nil, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C5056), id: 1) // "CLPV"
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
