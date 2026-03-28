import SwiftUI

public struct CommandWindowView: View {
    @ObservedObject private var state: CommandWindowState
    @State private var inputText = ""
    @State private var showConfirmation = false
    @State private var confirmationMessage = ""
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
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    
                    TextField("Remind me to... @10m", text: $inputText)
                        .font(.system(size: 28, weight: .ultraLight))
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
        .task(id: state.focusRequestID) {
            guard !showConfirmation else { return }

            // Focus can race with panel activation, so we nudge it twice.
            isInputFocused = false
            await Task.yield()
            isInputFocused = true

            try? await Task.sleep(for: .milliseconds(50))
            isInputFocused = true
        }
    }
}
