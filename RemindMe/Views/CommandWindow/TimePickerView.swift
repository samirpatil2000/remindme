import SwiftUI

public struct TimePickerView: View {
    @ObservedObject var recentStore: RecentTimesStore
    public var onApply: (TimeInterval) -> Void
    
    @State private var selectedIndex: Int? = nil
    
    private let presetMinutes: [Int] = [2, 5, 10, 15, 30, 60, 120]
    
    public init(recentStore: RecentTimesStore, onApply: @escaping (TimeInterval) -> Void) {
        self.recentStore = recentStore
        self.onApply = onApply
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MORE DURATIONS")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Color.primary.opacity(0.25))
            
            HStack(spacing: 8) {
                ForEach(presetMinutes, id: \.self) { min in
                    let time = TimeInterval(min * 60)
                    DurationPill(
                        time: time,
                        isSelected: selectedIndex == Int(time)
                    ) {
                        applyTime(time)
                    }
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.clear)
    }
    
    private func applyTime(_ time: TimeInterval) {
        let key = Int(time)
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            selectedIndex = key
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onApply(time)
        }
    }
}

// MARK: - Duration Pill

private struct DurationPill: View {
    let time: TimeInterval
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Text(formatTimeInterval(time))
                .font(.system(size: 13, weight: isSelected ? .medium : .regular, design: .rounded))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(isHovering ? 0.7 : 0.45))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(background)
                .clipShape(Capsule())
                .scaleEffect(isSelected ? 1.04 : (isHovering ? 1.02 : 1.0))
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovering)
                .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
    
    @ViewBuilder
    private var background: some View {
        if isSelected {
            Capsule()
                .fill(Color.accentColor.opacity(0.12))
                .overlay(Capsule().stroke(Color.accentColor.opacity(0.4), lineWidth: 1))
        } else {
            Capsule()
                .fill(Color.primary.opacity(isHovering ? 0.08 : 0.05))
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        
        if h > 0 && m == 0 { return "\(h)h" }
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
