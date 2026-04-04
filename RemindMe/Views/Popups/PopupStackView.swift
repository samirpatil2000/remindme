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
            VStack(alignment: .leading, spacing: 14) {
                // Title + timestamp
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.body.weight(.medium))
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
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(PopupPrimaryActionButtonStyle())

                    Button {
                        dismissWithAnimation(onStillRunning)
                    } label: {
                        Text("Still Running (10m)")
                    }
                    .buttonStyle(PopupSecondaryActionButtonStyle())
                }
                .disabled(isDismissing)

                // Snooze row — always visible
                HStack(spacing: 7) {
                    ForEach([2, 5, 15, 60], id: \.self) { mins in
                        SnoozeChip(label: mins < 60 ? "\(mins)m" : "1h") {
                            dismissWithAnimation { onSnooze(mins) }
                        }
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .frame(width: 380)
        .background(Color.clear)
        .scaleEffect(isDismissing ? 0.96 : 1.0)
        .offset(y: isDismissing ? 6 : 0)
        .opacity(isDismissing ? 0 : 1)
        .animation(.easeIn(duration: 0.25), value: isDismissing)
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

        withAnimation(.easeIn(duration: 0.25)) {
            isDismissing = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            action()
        }
    }
}

private struct SnoozeChipStyle: ButtonStyle {
    let isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .foregroundStyle(
                isHovering
                    ? Color(nsColor: .systemOrange)
                    : Color(nsColor: .tertiaryLabelColor)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isHovering
                            ? Color(nsColor: .systemOrange).opacity(0.12)
                            : Color(nsColor: .quaternaryLabelColor).opacity(0.65)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : (isHovering ? 1.06 : 1.0))
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct PopupPrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PopupActionButton(configuration: configuration, hoverStyle: .done)
    }
}

private struct PopupSecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PopupActionButton(configuration: configuration, hoverStyle: .stillRunning)
    }
}

private enum PopupActionHoverStyle {
    case done
    case stillRunning
}

private struct PopupActionButton: View {
    let configuration: ButtonStyle.Configuration
    let hoverStyle: PopupActionHoverStyle
    @State private var isHovering = false

    private var backgroundColor: Color {
        guard isHovering else { return Color(nsColor: .controlColor) }

        switch hoverStyle {
        case .done:
            return Color(nsColor: .controlAccentColor)
        case .stillRunning:
            return Color(nsColor: .systemOrange).opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        guard isHovering else { return Color(nsColor: .labelColor) }

        switch hoverStyle {
        case .done:
            return .white
        case .stillRunning:
            return Color(nsColor: .systemOrange)
        }
    }

    var body: some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor)
            )
            .foregroundStyle(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isHovering = hovering
                }
            }
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SnoozeChip: View {
    let label: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(label, action: action)
            .buttonStyle(SnoozeChipStyle(isHovering: isHovering))
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isHovering = hovering
                }
            }
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
