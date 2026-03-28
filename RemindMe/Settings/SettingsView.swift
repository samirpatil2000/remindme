import SwiftUI
import AppKit
import ServiceManagement

public struct ShortcutRecorder: NSViewRepresentable {
    @Binding public var shortcut: Shortcut
    public var onRecordingChanged: (Bool) -> Void
    
    public func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.shortcut = shortcut
        view.onShortcutChanged = { newShortcut in
            self.shortcut = newShortcut
        }
        view.onRecordingChanged = onRecordingChanged
        return view
    }
    
    public func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.shortcut = shortcut
    }
}

public class ShortcutRecorderNSView: NSView {
    public var shortcut: Shortcut = .defaultShortcut {
        didSet { needsDisplay = true }
    }
    public var onShortcutChanged: ((Shortcut) -> Void)?
    public var onRecordingChanged: ((Bool) -> Void)?
    
    private var isRecording = false {
        didSet {
            needsDisplay = true
            onRecordingChanged?(isRecording)
        }
    }
    
    public override var acceptsFirstResponder: Bool { true }
    
    public override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
        if isRecording {
            NSColor.controlAccentColor.setStroke()
            NSColor.controlAccentColor.withAlphaComponent(0.2).setFill()
        } else {
            NSColor.separatorColor.setStroke()
            NSColor.windowBackgroundColor.setFill()
        }
        path.lineWidth = 2
        path.stroke()
        path.fill()
        
        let text = isRecording ? "Type new shortcut" : string(for: shortcut)
        let font = NSFont.systemFont(ofSize: 13)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
        let size = text.size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        text.draw(at: point, withAttributes: attrs)
    }
    
    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }
    
    public override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }
    
    public override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.isEmpty || flags == .capsLock {
            NSSound.beep()
            return
        }
        let newShortcut = Shortcut(keyCode: event.keyCode, modifiers: flags.rawValue)
        self.shortcut = newShortcut
        onShortcutChanged?(newShortcut)
        isRecording = false
        window?.makeFirstResponder(nil)
    }
    
    private func string(for shortcut: Shortcut) -> String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: shortcut.modifiers)
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        
        if shortcut.keyCode == 49 {
            parts.append("Space")
        } else if shortcut.keyCode == 36 {
            parts.append("Return")
        } else if shortcut.keyCode == 53 {
            parts.append("Esc")
        } else {
            parts.append("Key \(shortcut.keyCode)")
        }
        
        return parts.joined(separator: " ")
    }
}

public struct SettingsView: View {
    @AppStorage("defaultReminderMinutes") private var defaultMinutes = 10
    @AppStorage("useSystemNotifications") private var useSystemNotifications = false
    
    @Binding public var currentShortcut: Shortcut
    @State private var isRecording = false
    
    public init(shortcut: Binding<Shortcut>) {
        self._currentShortcut = shortcut
    }
    
    public var body: some View {
        Form {
            Section(header: Text("General")) {
                HStack {
                    Text("Global Hotkey:")
                    ShortcutRecorder(shortcut: $currentShortcut, onRecordingChanged: { rec in
                        isRecording = rec
                    })
                    .frame(width: 200, height: 24)
                }
                
                Stepper("Default Duration: \(defaultMinutes) minutes", value: $defaultMinutes, in: 1...120)
                
                Toggle("Launch at Login", isOn: Binding(get: {
                    SMAppService.mainApp.status == .enabled
                }, set: { newValue in
                    if newValue {
                        try? SMAppService.mainApp.register()
                    } else {
                        try? SMAppService.mainApp.unregister()
                    }
                }))
                
                Toggle("Use System Notifications", isOn: $useSystemNotifications)
            }
            .padding(.bottom)
            
            if !PermissionsManager.isAccessibilityGranted() {
                Section(header: Text("Permissions")) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        Text("Accessibility access required for global hotkey")
                        Spacer()
                        Button("Grant Access") {
                            PermissionsManager.requestAccessibility()
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 450, height: 300)
    }
}
