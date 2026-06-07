import SwiftUI

public struct BatteryPopupView: View {
    public let message: String
    public let onDismiss: () -> Void
    @State private var isDismissing = false
    @State private var isHovering = false

    public init(message: String, onDismiss: @escaping () -> Void) {
        self.message = message
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with Warning Icon & Title
                HStack(spacing: 10) {
                    Image(systemName: "battery.25")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.red)
                    
                    Text("Low Battery Alert")
                        .font(.headline)
                        .foregroundStyle(Color(nsColor: .labelColor))
                }
                
                // Alert message
                Text(message)
                    .font(.body)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: 0)
                
                // OK button
                Button(action: {
                    dismissWithAnimation()
                }) {
                    Text("OK")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isHovering ? Color(nsColor: .controlAccentColor) : Color(nsColor: .controlColor))
                        )
                        .foregroundStyle(isHovering ? .white : Color(nsColor: .labelColor))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isHovering = hovering
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(width: 380, height: 160)
        .background(Color.clear)
        .scaleEffect(isDismissing ? 0.96 : 1.0)
        .offset(y: isDismissing ? 6 : 0)
        .opacity(isDismissing ? 0 : 1)
        .animation(.easeIn(duration: 0.25), value: isDismissing)
    }

    private func dismissWithAnimation() {
        guard !isDismissing else { return }

        withAnimation(.easeIn(duration: 0.25)) {
            isDismissing = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            onDismiss()
        }
    }
}
