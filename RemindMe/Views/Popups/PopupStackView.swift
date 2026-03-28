import SwiftUI

public struct PopupStackView: View {
    public let title: String
    public let firedAt: Date = Date()
    public let onDone: () -> Void
    public let onSnooze: (Int) -> Void
    public let onStillRunning: () -> Void
    @State private var isDismissing = false

    public init(title: String, onDone: @escaping () -> Void, onSnooze: @escaping (Int) -> Void, onStillRunning: @escaping () -> Void) {
        self.title = title
        self.onDone = onDone
        self.onSnooze = onSnooze
        self.onStillRunning = onStillRunning
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top accent stripe
            Rectangle()
                .fill(Color(nsColor: .controlAccentColor))
                .frame(height: 3)

            VStack(alignment: .leading, spacing: 14) {
                // Title + timestamp
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color(nsColor: .labelColor))
                        .lineLimit(2)

                    TimelineView(.periodic(from: Date(), by: 1.0)) { context in
                        Text(timeAgoString(from: firedAt, to: context.date))
                            .font(.footnote)
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
                }

                // Primary actions
                HStack(spacing: 8) {
                    Button {
                        dismissWithAnimation(onDone)
                    } label: {
                        Label("Done", systemImage: "checkmark")
                    }
                    .buttonStyle(PopupPrimaryActionButtonStyle())

                    Button {
                        dismissWithAnimation(onStillRunning)
                    } label: {
                        Text("Still Running")
                    }
                    .buttonStyle(PopupSecondaryActionButtonStyle())
                }
                .disabled(isDismissing)

                // Snooze row
                HStack(spacing: 7) {
                    Text("Snooze")
                        .font(.caption)
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))

                    ForEach([5, 15, 60], id: \.self) { mins in
                        Button(mins < 60 ? "\(mins)m" : "1h") { onSnooze(mins) }
                            .buttonStyle(SnoozeChipStyle())
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 18)
        }
        .frame(width: 380)
        .background(Color.clear)
        .scaleEffect(isDismissing ? 0.96 : 1.0)
        .opacity(isDismissing ? 0 : 1)
    }

    private func timeAgoString(from date: Date, to now: Date) -> String {
        let diff = Int(now.timeIntervalSince(date))
        if diff < 60 { return "Fired just now" }
        let mins = diff / 60
        if mins < 60 { return "Fired \(mins)m ago" }
        return "Fired \(mins / 60)h \(mins % 60)m ago"
    }

    private func dismissWithAnimation(_ action: @escaping () -> Void) {
        guard !isDismissing else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isDismissing = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            action()
        }
    }
}

private struct SnoozeChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .separatorColor).opacity(configuration.isPressed ? 0.5 : 0.3))
            )
    }
}

private struct PopupPrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlAccentColor))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

private struct PopupSecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(nsColor: .separatorColor).opacity(0.4))
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

public struct MoreIndicatorView: View {
    public let count: Int
    public let onClick: () -> Void
    
    public init(count: Int, onClick: @escaping () -> Void) {
        self.count = count
        self.onClick = onClick
    }
    
    public var body: some View {
        Button(action: onClick) {
            Label("+\(count) more pending", systemImage: "tray.full.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(nsColor: .labelColor))
                .padding(12)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .frame(width: 380)
    }
}
