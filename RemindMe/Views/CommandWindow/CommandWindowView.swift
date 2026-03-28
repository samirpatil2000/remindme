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
                Text(confirmationMessage)
                    .font(.title2)
                    .foregroundStyle(Color(nsColor: .labelColor))
                    .transition(.opacity)
            } else {
                TextField("Remind me to... @10m", text: $inputText)
                    .font(.system(size: 24, weight: .light))
                    .textFieldStyle(.plain)
                    .onSubmit {
                        let text = inputText
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSubmit(text)
                            withAnimation(.easeIn(duration: 0.15)) {
                                confirmationMessage = "Saved."
                                showConfirmation = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                onEscape()
                                inputText = ""
                                showConfirmation = false
                            }
                        }
                    }
            }
        }
        .padding(24)
        .frame(width: 480, height: 80)
    }
}
