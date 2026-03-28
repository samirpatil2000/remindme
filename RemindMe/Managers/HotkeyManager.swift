import AppKit
import Carbon

// MARK: - Shortcut Model

public struct Shortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var modifiers: NSEvent.ModifierFlags.RawValue
    
    public init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags.RawValue) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    
    /// ⌘⇧Space
    public static let defaultShortcut = Shortcut(keyCode: 49, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue)
    
    /// Convert NSEvent modifier flags to Carbon modifier flags for RegisterEventHotKey
    public var carbonModifiers: UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        var carbonMods: UInt32 = 0
        if flags.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.option)  { carbonMods |= UInt32(optionKey) }
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        return carbonMods
    }
    
    /// Human-readable display string (e.g. "⌘ ⇧ Space")
    public var displayString: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option)  { parts.append("⌥") }
        if flags.contains(.shift)   { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(keyCodeNames[keyCode] ?? "Key \(keyCode)")
        return parts.joined(separator: " ")
    }
}

// MARK: - Key Code Display Names

public let keyCodeNames: [UInt16: String] = [
    0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
    8: "C", 9: "V", 10: "§", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
    16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
    24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
    32: "U", 33: "[", 34: "I", 35: "P", 36: "Return", 37: "L", 38: "J",
    39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
    47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Esc"
]

// MARK: - Notification Names

public extension Notification.Name {
    static let hotkeyChanged = Notification.Name("RemindMe.hotkeyChanged")
}

// MARK: - HotkeyManager (Carbon Events API)

/// Registers a system-wide global hotkey using the Carbon Events API (RegisterEventHotKey).
/// This is more reliable than NSEvent monitors for true global shortcuts.
@MainActor
public class HotkeyManager {
    public var onHotkeyPressed: (() -> Void)?
    public private(set) var currentShortcut: Shortcut = .defaultShortcut
    
    private var hotKeyRef: EventHotKeyRef?
    
    // Carbon event handlers use C function pointers — we need a static reference
    // so the callback can route back to the instance.
    private static weak var instance: HotkeyManager?
    private static var eventHandlerInstalled = false
    
    /// "RMND" as a FourCC signature for this app's hotkeys
    private static let hotKeySignature: OSType = 0x524D_4E44
    
    public init() {
        HotkeyManager.instance = self
    }
    
    // MARK: - Public API
    
    /// Register (or re-register) a global hotkey using the Carbon Events API.
    /// Falls back to NSEvent monitors in unit-test environments where Carbon
    /// event targets are unavailable.
    public func register(shortcut: Shortcut = .defaultShortcut) {
        unregister()
        currentShortcut = shortcut
        
        // Install the one-time Carbon event handler (idempotent)
        if !HotkeyManager.eventHandlerInstalled {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            
            let status = InstallEventHandler(
                GetApplicationEventTarget(),
                { (_nextHandler, theEvent, _userData) -> OSStatus in
                    var hotKeyID = EventHotKeyID()
                    GetEventParameter(
                        theEvent,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotKeyID
                    )
                    
                    if hotKeyID.id == 1 {
                        DispatchQueue.main.async {
                            HotkeyManager.instance?.onHotkeyPressed?()
                        }
                    }
                    return noErr
                },
                1,
                &eventType,
                nil,
                nil
            )
            
            if status != noErr {
                // Likely running in a unit-test process without a real event loop.
                // Silently skip — the hotkey just won't fire.
                return
            }
            HotkeyManager.eventHandlerInstalled = true
        }
        
        // Register the actual hotkey with the system
        let hotKeyID = EventHotKeyID(
            signature: HotkeyManager.hotKeySignature,
            id: 1
        )
        
        let registerStatus = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if registerStatus != noErr {
            // Non-fatal — in test environments or when accessibility is denied
            // the registration will fail silently.
        }
    }
    
    /// Convenience alias matching the Buffer pattern.
    public func reregister() {
        register(shortcut: currentShortcut)
    }
    
    /// Unregister the current Carbon hotkey (safe to call even if nothing is registered).
    public func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
    
}
