import SwiftUI

public struct PopupStackView: View {
    public let title: String
    public let onDone: () -> Void
    public let onSnooze: () -> Void
    public let onStillRunning: () -> Void
    
    public init(title: String, onDone: @escaping () -> Void, onSnooze: @escaping () -> Void, onStillRunning: @escaping () -> Void) {
        self.title = title
        self.onDone = onDone
        self.onSnooze = onSnooze
        self.onStillRunning = onStillRunning
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "stopwatch")
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color(nsColor: .labelColor))
                    .lineLimit(1)
            }
            
            Text("Reminder fired")
                .font(.subheadline)
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            
            HStack {
                Button("Done", action: onDone)
                Button("Snooze 5m", action: onSnooze)
                Button("Still Running", action: onStillRunning)
            }
            .font(.body)
            .tint(Color(nsColor: .controlAccentColor))
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 320)
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
            Text("+\(count) more")
                .font(.subheadline)
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .padding(8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .frame(width: 320)
    }
}
