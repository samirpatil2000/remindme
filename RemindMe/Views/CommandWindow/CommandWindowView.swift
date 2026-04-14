import SwiftUI

public struct CommandWindowView: View {
    @ObservedObject private var state: CommandWindowState
    @State private var inputText = ""
    @State private var showConfirmation = false
    @State private var confirmedTaskTitle = ""
    @State private var confirmedTaskTime = ""
    @State private var window: NSWindow?
    @State private var hasFocusedCurrentPresentation = false
    @State private var hasAppliedInitialFocusDelay = false
    @FocusState private var isInputFocused: Bool

    @State private var selectedDuration: TimeInterval? = nil
    @State private var showTimePicker = false
    @StateObject private var recentStore = RecentTimesStore()
    
    @AppStorage("commandWindowUsageCount") private var usageCount: Int = 0
    @AppStorage("defaultReminderMinutes") private var defaultMinutes: Int = 10
    @State private var tabPressCount: Int = 0
    @State private var recentIndex: Int = 0
    @State private var hasUserOverriddenDuration: Bool = false

    private var invalidTokenDetected: Bool {
        guard !inputText.isEmpty, selectedDuration == nil else { return false }
        let pattern = "(?:^|\\s)(@[^\\s]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let matches = regex.matches(in: inputText, range: NSRange(inputText.startIndex..., in: inputText))
        var sawAnyAt = false
        var sawValidAt = false
        
        for match in matches {
            sawAnyAt = true
            let tokenNSRange = match.range(at: 1)
            if let tokenRange = Range(tokenNSRange, in: inputText) {
                let tokenStr = String(inputText[tokenRange])
                if TimeToken(fromString: tokenStr) != nil {
                    sawValidAt = true
                    break
                }
            }
        }
        return sawAnyAt && !sawValidAt
    }

    // MARK: - Displayed duration resolution
    
    private var displayedDuration: TimeInterval? {
        if hasUserOverriddenDuration, let sel = selectedDuration { return sel }
        if inputText.contains("@") {
            if case .success(let payload) = ReminderParser.parse(inputText) {
                let diff = payload.firesAt.timeIntervalSinceNow
                if diff > 0 && inputText.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                    if !invalidTokenDetected { return round(diff) }
                }
            }
            return nil
        }
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return recentStore.recentTimes.first ?? TimeInterval(defaultMinutes * 60)
    }
    
    private var durationColor: Color {
        hasUserOverriddenDuration || inputText.contains("@") ? Color.accentColor : Color.primary.opacity(0.7)
    }

    public var onSubmit: (String, TimeInterval?) -> Void
    public var onEscape: () -> Void
    public var onTogglePicker: ((Bool) -> Void)?

    public init(state: CommandWindowState, onSubmit: @escaping (String, TimeInterval?) -> Void, onEscape: @escaping () -> Void, onTogglePicker: ((Bool) -> Void)? = nil) {
        self.state = state
        self.onSubmit = onSubmit
        self.onEscape = onEscape
        self.onTogglePicker = onTogglePicker
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if showConfirmation {
                    confirmationView
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                } else {
                    inputRow
                }
            }
            .frame(height: 72)

            if !showConfirmation, let hint = hintText {
                hintBar(for: hint, isWarning: invalidTokenDetected)
                    .transition(.opacity)
            }

            if showTimePicker {
                Divider().padding(.horizontal, 24)
                TimePickerView(recentStore: recentStore) { duration in
                    withAnimation {
                        selectedDuration = duration
                        hasUserOverriddenDuration = true
                        togglePicker()
                        recentStore.add(duration)
                        isInputFocused = true
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .frame(height: 80)
            }
        }
        .frame(width: 560)
        .background(WindowAccessor(window: $window))
        .onChange(of: inputText) { _, newValue in
            tabPressCount = 0
            recentIndex = 0
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                hasUserOverriddenDuration = false
                selectedDuration = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CommandWindowTabPressed"))) { _ in
            handleTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            guard notification.object as AnyObject? === window else { return }
            hasFocusedCurrentPresentation = false
            isInputFocused = false
            if showTimePicker { togglePicker() }
        }
        .task(id: state.focusRequestID) {
            guard !showConfirmation else { return }
            guard let targetWindow = window ?? NSApp.keyWindow ?? NSApp.mainWindow, targetWindow.isVisible else { return }
            guard !hasFocusedCurrentPresentation else { return }

            hasFocusedCurrentPresentation = true
            isInputFocused = false

            if !hasAppliedInitialFocusDelay {
                try? await Task.sleep(for: .milliseconds(50))
                hasAppliedInitialFocusDelay = true
            }

            await Task.yield()
            isInputFocused = true
        }
    }
    
    // MARK: - Input Row
    
    private var inputRow: some View {
        HStack(spacing: 14) {
            TextField("", text: $inputText)
                .font(.system(size: 21, weight: .light))
                .tracking(-0.2)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.primary.opacity(0.88))
                .focused($isInputFocused)
                .overlay(alignment: .leading) {
                    if inputText.isEmpty {
                        Text("Remind me to...")
                            .font(.system(size: 21, weight: .light))
                            .tracking(-0.2)
                            .foregroundStyle(Color.primary.opacity(0.22))
                            .allowsHitTesting(false)
                    }
                }
                .onSubmit { submitTask() }

            if let duration = displayedDuration {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(formatCompactDuration(duration))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(durationColor)
                        .animation(.easeOut(duration: 0.15), value: durationColor)

                    if !inputText.isEmpty && recentStore.recentTimes.count >= 2 {
                        HStack(spacing: 5) {
                            ForEach(0..<min(3, recentStore.recentTimes.count), id: \.self) { i in
                                Circle()
                                    .fill(dotColor(for: i))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.top, 3)
                        .animation(.easeOut(duration: 0.15), value: tabPressCount)
                        .animation(.easeOut(duration: 0.15), value: recentIndex)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 28)
    }
    
    // MARK: - Dot Color
    
    private func dotColor(for index: Int) -> Color {
        guard tabPressCount > 0 else { return Color.primary.opacity(0.15) }
        if index == recentIndex { return Color.accentColor }
        if index < tabPressCount { return Color.primary.opacity(0.4) }
        return Color.primary.opacity(0.15)
    }
    
    // MARK: - Compact Duration Formatter
    
    private func formatCompactDuration(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        if h > 0 && m == 0 { return "\(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m) min" }
        return "\(s)s"
    }
    
    // MARK: - Hint Bar
    
    private static let warmAmber = Color(hue: 0.08, saturation: 0.85, brightness: 1.0)
    
    private func hintBar(for hint: String, isWarning: Bool = false) -> some View {
        let textColor = isWarning ? Self.warmAmber.opacity(0.85) : Color.primary.opacity(0.28)
        let badgeText = isWarning ? Self.warmAmber.opacity(0.9) : Color.primary.opacity(0.45)
        let badgeBg   = isWarning ? Self.warmAmber.opacity(0.10) : Color.primary.opacity(0.06)
        let badgeBorder = isWarning ? Self.warmAmber.opacity(0.25) : Color.primary.opacity(0.1)
        
        return HStack(spacing: 6) {
            if isWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Self.warmAmber.opacity(0.8))
            }
            ForEach(parseHint(hint)) { seg in
                if seg.isKey {
                    Text(seg.text)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(badgeText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(badgeBorder, lineWidth: 1)
                        )
                        .cornerRadius(4)
                } else {
                    Text(seg.text)
                        .font(.system(size: 12))
                        .foregroundStyle(textColor)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.top, 2)
        .padding(.bottom, 14)
        .animation(.easeInOut(duration: 0.2), value: hint)
    }
    
    // MARK: - Hint Parsing
    
    private func parseHint(_ hint: String) -> [HintSegment] {
        var segments: [HintSegment] = []
        let nsHint = hint as NSString
        guard let regex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]") else {
            return [HintSegment(text: hint, isKey: false)]
        }
        var lastEnd = 0
        regex.enumerateMatches(in: hint, range: NSRange(location: 0, length: nsHint.length)) { match, _, _ in
            guard let match = match else { return }
            if match.range.location > lastEnd {
                let plain = nsHint.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
                segments.append(HintSegment(text: plain, isKey: false))
            }
            segments.append(HintSegment(text: nsHint.substring(with: match.range(at: 1)), isKey: true))
            lastEnd = match.range.location + match.range.length
        }
        if lastEnd < nsHint.length {
            segments.append(HintSegment(text: nsHint.substring(from: lastEnd), isKey: false))
        }
        return segments
    }
    
    // MARK: - Confirmation View
    
    private var confirmationView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.green.opacity(0.15)).frame(width: 28, height: 28)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color.green)
            }
            HStack(spacing: 6) {
                Text(confirmedTaskTitle)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !confirmedTaskTime.isEmpty {
                    Text(confirmedTaskTime)
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Color.primary.opacity(0.3))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
    }
    
    // MARK: - Hint Text
    
    private var hintText: String? {
        if inputText.contains("@") && !invalidTokenDetected && selectedDuration == nil {
            return "Try [@10m]  [@1h30m]  [@2h]"
        }
        if invalidTokenDetected {
            return "That's not a valid time. Try [@10m]"
        }
        switch usageCount {
        case 0: return "Type a task, press [Enter] to set a \(defaultMinutes) min reminder"
        case 1...3: return "[Tab] change time   [Enter] set reminder"
        default: return nil
        }
    }
    
    // MARK: - Tab Handler
    
    private func handleTab() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let recents = Array(recentStore.recentTimes.prefix(3))
        guard !recents.isEmpty else {
            if !showTimePicker { togglePicker() }
            return
        }
        tabPressCount += 1
        if tabPressCount <= recents.count {
            recentIndex = tabPressCount - 1
            withAnimation(.easeOut(duration: 0.15)) {
                selectedDuration = recents[recentIndex]
                hasUserOverriddenDuration = true
            }
        } else {
            tabPressCount = 0
            if !showTimePicker { togglePicker() }
        }
    }
    
    // MARK: - Submit
    
    private func submitTask() {
        let text = inputText
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let duration = selectedDuration ?? displayedDuration
            onSubmit(text, duration)
            if let d = duration { recentStore.add(d) }
            
            var savedTitle = text.trimmingCharacters(in: .whitespacesAndNewlines)
            var finalDuration = duration
            
            if duration == nil {
                if case .success(let payload) = ReminderParser.parse(text) {
                    savedTitle = payload.title
                    finalDuration = round(payload.firesAt.timeIntervalSinceNow)
                }
            }
            
            usageCount += 1
            
            withAnimation(.easeIn(duration: 0.15)) {
                confirmedTaskTitle = savedTitle
                if let dur = finalDuration, dur > 0 {
                    confirmedTaskTime = "in \(formatDetailedDuration(dur))"
                } else {
                    confirmedTaskTime = ""
                }
                
                showConfirmation = true
                if showTimePicker { togglePicker() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                // Hide the window first — keeps the checkmark visible during the fade-out
                onEscape()
                // Reset state after the window is fully gone
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    inputText = ""
                    selectedDuration = nil
                    hasUserOverriddenDuration = false
                    showConfirmation = false
                }
            }
        }
    }
    
    // MARK: - Toggle Picker
    
    private func togglePicker() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showTimePicker.toggle()
        }
        onTogglePicker?(showTimePicker)
    }
    
    // MARK: - Detailed Duration Formatter
    
    private func formatDetailedDuration(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        
        var parts = [String]()
        if h == 1 { parts.append("1 hour") } else if h > 1 { parts.append("\(h) hours") }
        if m == 1 { parts.append("1 minute") } else if m > 1 { parts.append("\(m) minutes") }
        if s == 1 { parts.append("1 second") } else if s > 1 { parts.append("\(s) seconds") }
        
        return parts.joined(separator: " ")
    }
}

// MARK: - Supporting Types

private struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            window = view.window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            window = nsView.window
        }
    }
}

private struct HintSegment: Identifiable {
    let id = UUID()
    let text: String
    let isKey: Bool
}
