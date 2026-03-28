import SwiftUI

public struct CommandWindowView: View {
    @State private var inputText = ""
    @State private var showConfirmation = false
    @State private var confirmationMessage = ""
    
    public var onSubmit: (String) -> Void
    public var onEscape: () -> Void
    
    public init(onSubmit: @escaping (String) -> Void, onEscape: @escaping () -> Void) {
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
                            Text("⌘")
                            Text("⇧")
                            Text("Space")
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
    }
}
