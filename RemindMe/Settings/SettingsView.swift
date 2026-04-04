import SwiftUI
import AppKit
import ServiceManagement

// MARK: - ShortcutRecorder (matches Buffer's KeyRecorder pattern exactly)

/// Invisible NSViewRepresentable placed as .background() on the settings view.
/// When isRecording is true, updateNSView makes the view first responder to capture keys.
public struct ShortcutRecorder: NSViewRepresentable {
    @Binding public var isRecording: Bool
    public let onRecord: (Shortcut) -> Void

    public func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onRecord = onRecord
        return view
    }

    public func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.isRecording = isRecording
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

public class ShortcutRecorderNSView: NSView {
    var isRecording = false
    var onRecord: ((Shortcut) -> Void)?

    public override var acceptsFirstResponder: Bool { true }

    // Match Buffer's KeyRecorderView.viewDidMoveToWindow — force activation
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window = self.window {
            window.level = .floating
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    public override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        // Ignore modifier-only presses (Shift=56, Control=59, Option=58, Command=55)
        if event.keyCode == 56 || event.keyCode == 59 || event.keyCode == 58 || event.keyCode == 55 {
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.isEmpty || flags == .capsLock {
            NSSound.beep()
            return
        }

        let newShortcut = Shortcut(keyCode: event.keyCode, modifiers: flags.rawValue)
        onRecord?(newShortcut)
    }
}

// MARK: - SettingsView

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
                GroupBox(label: Text("GENERAL").font(.caption2).foregroundStyle(.secondary)) {
                    VStack(alignment: .leading, spacing: 12) {

                        // MARK: Shortcut row
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 12) {
                                Text("Global hotkey")

                                Spacer()

                                // Key badges
                                HStack(spacing: 4) {
                                    let parts = currentShortcut.displayString.split(separator: " ")
                                    ForEach(0..<parts.count, id: \.self) { i in
                                        Text(String(parts[i]))
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(
                                                isRecording
                                                    ? Color.accentColor.opacity(0.15)
                                                    : Color(NSColor.controlBackgroundColor)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(
                                                        isRecording ? Color.accentColor : Color.gray.opacity(0.3),
                                                        lineWidth: 1
                                                    )
                                            )
                                            .cornerRadius(6)
                                    }
                                }

                                Button(isRecording ? "Cancel" : "Change") {
                                    isRecording.toggle()
                                }
                                .buttonStyle(.bordered)
                            }

                            if isRecording {
                                Text("Press your new shortcut…")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                                    .transition(.opacity)
                            }
                        }
                        .animation(.easeInOut(duration: 0.15), value: isRecording)
                        .onChange(of: isRecording) { _, recording in
                            NotificationCenter.default.post(
                                name: recording
                                    ? Notification.Name("HotkeyRecordingBegan")
                                    : Notification.Name("HotkeyRecordingEnded"),
                                object: nil
                            )
                        }

                        Divider()

                        // MARK: Default duration
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

                        // MARK: Launch at Login
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
        .frame(width: 520, height: 360)
        // Buffer pattern: invisible KeyRecorder as .background() on the entire view
        .background(
            ShortcutRecorder(isRecording: $isRecording) { newShortcut in
                currentShortcut = newShortcut
                isRecording = false
            }
        )
    }
}
