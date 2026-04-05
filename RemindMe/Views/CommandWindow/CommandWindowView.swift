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
    @State private var isHoveringClock = false
    @State private var suppressSuggestion = false
    
    private var suggestedDuration: TimeInterval? {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || suppressSuggestion || selectedDuration != nil || inputText.contains("@") {
            return nil
        }
        return recentStore.recentTimes.first
    }
    
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

    public var onSubmit: (String, TimeInterval?) -> Void
    public var onEscape: () -> Void
    public var onTogglePicker: ((Bool) -> Void)?

    public init(state: CommandWindowState, onSubmit: @escaping (String, TimeInterval?) -> Void, onEscape: @escaping () -> Void, onTogglePicker: ((Bool) -> Void)? = nil) {
        self.state = state
        self.onSubmit = onSubmit
        self.onEscape = onEscape
        self.onTogglePicker = onTogglePicker
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if showConfirmation {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                        
                        HStack(spacing: 6) {
                            Text(confirmedTaskTitle)
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            if !confirmedTaskTime.isEmpty {
                                Text(confirmedTaskTime)
                                    .font(.system(size: 18, weight: .light))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                } else {
                    HStack(spacing: 16) {

                        
                        TextField("Remind me to... @5m", text: $inputText)
                            .font(.system(size: 20, weight: .light))
                            .textFieldStyle(.plain)
                            .focused($isInputFocused)
                            .onChange(of: inputText) { _, newValue in
                                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    suppressSuggestion = false
                                }
                            }
                            .onSubmit {
                                submitTask()
                            }
                        
                        if let duration = selectedDuration {
                            TimeChip(duration: duration) {
                                withAnimation {
                                    selectedDuration = nil
                                    suppressSuggestion = true
                                }
                            }
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                        } else if invalidTokenDetected {
                            WarningChip()
                                .transition(.opacity)
                        } else if let suggestion = suggestedDuration {
                            SuggestedTimeChip(duration: suggestion) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedDuration = suggestion
                                }
                            }
                            .transition(.opacity)
                        }
                        
                        if inputText.isEmpty && selectedDuration == nil && suggestedDuration == nil {
                            HStack(spacing: 8) {
                                // Individual key badges
                                HStack(spacing: 4) {
                                    let parts = state.shortcutHint.split(separator: " ")
                                    ForEach(0..<parts.count, id: \.self) { i in
                                        Text(String(parts[i]))
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.gray.opacity(0.12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                            )
                                            .cornerRadius(4)
                                    }
                                }

                                // Settings gear
                                Button {
                                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                                    NSApp.activate(ignoringOtherApps: true)
                                } label: {
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 13, weight: .light))
                                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                                }
                                .buttonStyle(.plain)
                                .help("Settings")
                            }
                        } else {
                            // Clock button
                            Button {
                                togglePicker()
                            } label: {
                                Image(systemName: showTimePicker ? "clock.fill" : "clock")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(showTimePicker ? .accentColor : (isHoveringClock ? .primary : .secondary))
                                    .rotationEffect(.degrees(showTimePicker ? 45 : 0))
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showTimePicker)
                            }
                            .buttonStyle(.plain)
                            .onHover { isHoveringClock = $0 }
                            .padding(.trailing, 4)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .frame(height: 72)
            
            if showTimePicker {
                Divider()
                    .padding(.horizontal, 24)
                
                TimePickerView(recentStore: recentStore) { duration in
                    withAnimation {
                        selectedDuration = duration
                        togglePicker()
                        recentStore.add(duration)
                        isInputFocused = true
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .frame(height: 148)
            }
        }
        .frame(width: 560)
        .background(WindowAccessor(window: $window))
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CommandWindowTabPressed"))) { _ in
            if !showTimePicker { togglePicker() }
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
    
    private func submitTask() {
        let text = inputText
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let duration = selectedDuration ?? suggestedDuration
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // Hide the window first — keeps the checkmark visible during the fade-out
                onEscape()
                // Reset state after the window is fully gone
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    inputText = ""
                    selectedDuration = nil
                    suppressSuggestion = false
                    showConfirmation = false
                }
            }
        }
    }
    
    private func togglePicker() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showTimePicker.toggle()
        }
        onTogglePicker?(showTimePicker)
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        
        var parts = [String]()
        if h > 0 { parts.append("\(h)h") }
        if m > 0 || h == 0 { parts.append("\(m)m") }
        if s > 0 { parts.append("\(s)s") }
        
        return parts.joined(separator: " ")
    }
    
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

private struct TimeChip: View {
    let duration: TimeInterval
    let onRemove: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                if isHovering {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                } else {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .medium))
                }
                
                Text(formatTimeInterval(duration))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(.accentColor)
            .background(Color.accentColor.opacity(isHovering ? 0.15 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor.opacity(isHovering ? 0.4 : 0.2), lineWidth: 1)
            )
            .cornerRadius(6)
            .animation(.easeOut(duration: 0.1), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
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

private struct SuggestedTimeChip: View {
    let duration: TimeInterval
    let onConfirm: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onConfirm) {
            HStack(spacing: 4) {
                Text("in \(formatTimeInterval(duration))")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(.secondary)
            .background(Color.secondary.opacity(isHovering ? 0.2 : 0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .cornerRadius(6)
            .animation(.easeOut(duration: 0.1), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        
        if h > 0 && m == 0 { return "\(h)h" }
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if m == 0 && s > 0 { return "\(s)s" }
        if s > 0 { return "\(m)m \(s)s" }
        return "\(m) min"
    }
}

private struct WarningChip: View {
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11, weight: .medium))
                
            if isHovering {
                Text("Invalid time")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
            }
        }
        .padding(.horizontal, isHovering ? 8 : 6)
        .padding(.vertical, 4)
        .foregroundColor(Color(nsColor: .systemOrange))
        .background(Color(nsColor: .systemOrange).opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .systemOrange).opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(6)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { isHovering = $0 }
    }
}
