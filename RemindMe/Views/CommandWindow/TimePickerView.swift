import SwiftUI

public struct TimePickerView: View {
    @ObservedObject var recentStore: RecentTimesStore
    public var onApply: (TimeInterval) -> Void
    
    @State private var minutes: Int = 5
    @State private var seconds: Int = 0
    @State private var selectedIndex: Int? = nil
    
    private let presetMinutes: [Int] = [2, 5, 10, 15, 30, 60, 120]
    
    public init(recentStore: RecentTimesStore, onApply: @escaping (TimeInterval) -> Void) {
        self.recentStore = recentStore
        self.onApply = onApply
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Unified Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 12) {
                // Recent Items
                ForEach(recentStore.recentTimes.prefix(5), id: \.self) { time in
                    TimeBubble(time: time, isRecent: true, isSelected: selectedIndex == Int(time)) { time in
                        applyTime(time)
                    }
                }
                
                // Presets
                ForEach(presetMinutes, id: \.self) { min in
                    let time = TimeInterval(min * 60)
                    if !recentStore.recentTimes.prefix(5).contains(time) {
                        TimeBubble(time: time, isRecent: false, isSelected: selectedIndex == Int(time)) { time in
                            applyTime(time)
                        }
                    }
                }
            }
            
            Divider()
                .padding(.horizontal, -10)
                .opacity(0.5)
            
            // Minimal Custom Row
            HStack(spacing: 8) {
                Text("Custom")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    CustomTimeField(value: $minutes, max: 120)
                    Text("min").font(.system(size: 12)).foregroundColor(.secondary)
                }
                
                Spacer().frame(width: 8)
                
                HStack(spacing: 4) {
                    CustomTimeField(value: $seconds, max: 59)
                    Text("sec").font(.system(size: 12)).foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    let total = TimeInterval(minutes * 60 + seconds)
                    if total > 0 { applyTime(total) }
                }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(minutes == 0 && seconds == 0 ? Color(NSColor.tertiaryLabelColor) : Color.white)
                        .frame(width: 26, height: 26)
                        .background(minutes == 0 && seconds == 0 ? Color(NSColor.controlBackgroundColor) : Color.accentColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(minutes == 0 && seconds == 0)
            }
        }
        .padding(20)
        .background(Color.clear)
    }
    
    private func applyTime(_ time: TimeInterval) {
        let key = Int(time)
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            selectedIndex = key
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onApply(time)
        }
    }
}

private struct CustomTimeField: View {
    @Binding var value: Int
    let max: Int
    
    var body: some View {
        TextField("", value: $value, format: .number)
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .font(.system(size: 15, weight: .medium, design: .monospaced))
            .foregroundColor(.primary)
            .frame(width: 34, height: 24)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
            .cornerRadius(6)
            .onChange(of: value) { _, newValue in
                if newValue > max { value = max }
                if newValue < 0 { value = 0 }
            }
    }
}

private struct TimeBubble: View {
    let time: TimeInterval
    let isRecent: Bool
    let isSelected: Bool
    let action: (TimeInterval) -> Void
    
    @State private var isHovering = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: { action(time) }) {
            HStack(spacing: 4) {
                if isRecent {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                Text(formatTimeInterval(time))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(isSelected ? .accentColor : (isHovering ? .primary : .secondary))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(backgroundView)
            .scaleEffect(isSelected ? 1.05 : (isPressed ? 0.95 : (isHovering ? 1.02 : 1.0)))
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovering)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(SquishyButtonStyle(isPressed: $isPressed))
        .onHover { isHovering = $0 }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        let baseRect = RoundedRectangle(cornerRadius: 15)
        
        if isSelected {
            baseRect
                .fill(Color.accentColor.opacity(0.15))
                .overlay(baseRect.stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
        } else {
            baseRect
                .fill(isHovering ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        
        if h > 0 && m == 0 { return "\(h)h" }
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if m == 0 && s > 0 { return "\(s)s" }
        if s > 0 { return "\(m)m \(s)s" }
        return "\(m)m"
    }
}

private struct SquishyButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
    }
}
