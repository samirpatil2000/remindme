import AppKit

public struct Shortcut: Codable, Equatable {
    public var keyCode: UInt16
    public var modifiers: NSEvent.ModifierFlags.RawValue
    
    public init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags.RawValue) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    
    public static let defaultShortcut = Shortcut(keyCode: 49, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue)
}

public class HotkeyManager {
    public var onHotkeyPressed: (() -> Void)?
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    public var currentShortcut: Shortcut = .defaultShortcut
    
    public init() {}
    
    public func register(shortcut: Shortcut = .defaultShortcut) {
        unregister()
        currentShortcut = shortcut
        
        let desiredFlags = NSEvent.ModifierFlags(rawValue: shortcut.modifiers).intersection(.deviceIndependentFlagsMask)
        
        let localHandler: (NSEvent) -> NSEvent? = { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == desiredFlags && event.keyCode == shortcut.keyCode {
                self?.onHotkeyPressed?()
                return nil
            }
            return event
        }
        
        let globalHandler: (NSEvent) -> Void = { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == desiredFlags && event.keyCode == shortcut.keyCode {
                self?.onHotkeyPressed?()
            }
        }
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: globalHandler)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: localHandler)
    }
    
    public func unregister() {
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            globalMonitor = nil
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
            localMonitor = nil
        }
    }
}
