import SwiftUI

public struct CommandWindowView: View {
    @ObservedObject private var state: CommandWindowState
    @State private var inputText = ""
    @State private var showConfirmation = false
    @State private var confirmationMessage = ""
    @State private var window: NSWindow?
    @State private var hasFocusedCurrentPresentation = false
    @State private var hasAppliedInitialFocusDelay = false
    @FocusState private var isInputFocused: Bool

    public var onSubmit: (String) -> Void
    public var onEscape: () -> Void

    public init(state: CommandWindowState, onSubmit: @escaping (String) -> Void, onEscape: @escaping () -> Void) {
        self.state = state
        self.onSubmit = onSubmit
        self.onEscape = onEscape
    }
    
    public var body: some View {
        ZStack {
            if showConfirmation {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.green)
                    Text(confirmationMessage)
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(Color(nsColor: .labelColor))
                }
                .transition(.opacity)
            } else {
                HStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    
                    TextField("Remind me to... @10m", text: $inputText)
                        .font(.system(size: 28, weight: .ultraLight, design: .rounded))
                        .textFieldStyle(.plain)
                        .focused($isInputFocused)
                        .onSubmit {
                            let text = inputText
                            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSubmit(text)
                                withAnimation(.easeIn(duration: 0.15)) {
                                    confirmationMessage = "Saved: \(text)"
                                    showConfirmation = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    onEscape()
                                    inputText = ""
                                    showConfirmation = false
                                }
                            }
                        }
                    
                    if inputText.isEmpty {
                        // Keyboard shortcut hint
                        HStack(spacing: 4) {
                            let parts = state.shortcutHint.split(separator: " ")
                            ForEach(0..<parts.count, id: \.self) { i in
                                Text(String(parts[i]))
                            }
                        }
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .frame(width: 560, height: 72)
        .background(WindowAccessor(window: $window))
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            guard notification.object as AnyObject? === window else { return }
            hasFocusedCurrentPresentation = false
            isInputFocused = false
        }
        .task(id: state.focusRequestID) {
            guard !showConfirmation else { return }
            guard let targetWindow = window ?? NSApp.keyWindow ?? NSApp.mainWindow, targetWindow.isVisible else { return }
            guard !hasFocusedCurrentPresentation else { return }

            hasFocusedCurrentPresentation = true
            isInputFocused = false

            if !hasAppliedInitialFocusDelay {
                try? await Task.sleep(for: .milliseconds(50))
                hasAppliedInitialFocusDelay = true
            }

            await Task.yield()
            isInputFocused = true
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            window = view.window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            window = nsView.window
        }
    }
}
