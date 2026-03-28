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
        
        let text = isRecording ? "Type new shortcut" : shortcut.displayString
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
    
    // `string(for: shortcut)` was removed because `shortcut.displayString` is now universally available.
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
            // Fix 4 — GroupBox with uppercase caption label
            Section(header: Text("General")) {
                GroupBox(label: Text("GENERAL").font(.caption2).foregroundStyle(.secondary)) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Fix 2 — ShortcutRecorder constrained width
                        HStack {
                            Text("Global hotkey")
                            Spacer()
                            ShortcutRecorder(shortcut: $currentShortcut, onRecordingChanged: { rec in
                                isRecording = rec
                            })
                            .frame(width: 180, height: 28)
                        }
                        
                        Divider()
                        
                        // Fix 1 — Manual HStack for Stepper
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Default reminder duration")
                                    .font(.body)
                                Text("\(defaultMinutes) minutes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Stepper("", value: $defaultMinutes, in: 1...120)
                                .labelsHidden()
                        }
                        
                        Divider()
                        
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
                    .padding(8)
                }
            }
            .padding(.bottom)
        }
        .padding()
        .frame(width: 520, height: 340)
    }
}
