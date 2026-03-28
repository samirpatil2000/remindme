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
        HStack(spacing: 0) {
            // Accent Bar
            Rectangle()
                .fill(Color(nsColor: .controlAccentColor))
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    // Header Region
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(Color(nsColor: .labelColor))
                            .lineLimit(1)
                        
                        TimelineView(.periodic(from: Date(), by: 1.0)) { context in
                            Text(timeAgoString(from: firedAt, to: context.date))
                                .font(.subheadline)
                                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        }
                    }
                    
                    // Actions Region
                    HStack(spacing: 8) {
                        Button(action: onDone) {
                            Label("Done", systemImage: "checkmark")
                                .font(.body.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(nsColor: .controlAccentColor))
                                .foregroundStyle(.white)
                                .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: onStillRunning) {
                            Text("Still Running")
                                .font(.body)
                                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                                .underline()
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 4)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 6) {
                        Text("Snooze").font(.caption).foregroundStyle(.secondary)
                        ForEach([5, 15, 60], id: \.self) { mins in
                            Button(mins < 60 ? "\(mins)m" : "1h") { onSnooze(mins) }.buttonStyle(.bordered).controlSize(.mini)
                        }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(width: 360)
        .background(Color.clear)
    }
    
    private func timeAgoString(from date: Date, to now: Date) -> String {
        let diff = Int(now.timeIntervalSince(date))
        if diff < 60 {
            return "Fired just now"
        }
        let mins = diff / 60
        if mins < 60 {
            return "Fired \(mins)m ago"
        }
        return "Fired \(mins / 60)h \(mins % 60)m ago"
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
        .frame(width: 360)
    }
}
