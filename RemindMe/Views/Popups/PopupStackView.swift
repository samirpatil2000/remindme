import SwiftUI

public struct PopupStackView: View {
    public let title: String
    public let firedAt: Date = Date()
    public let onDone: () -> Void
    public let onSnooze: (Int) -> Void
    public let onStillRunning: () -> Void

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
                        .font(.title3.weight(.semibold))
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
                    Button(action: onDone) {
                        Label("Done", systemImage: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(nsColor: .controlAccentColor))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: onStillRunning) {
                        Text("Still Running")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(nsColor: .separatorColor).opacity(0.4))
                            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

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
    }

    private func timeAgoString(from date: Date, to now: Date) -> String {
        let diff = Int(now.timeIntervalSince(date))
        if diff < 60 { return "Fired just now" }
        let mins = diff / 60
        if mins < 60 { return "Fired \(mins)m ago" }
        return "Fired \(mins / 60)h \(mins % 60)m ago"
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
