import SwiftUI

public struct CommandWindowView: View {
    @ObservedObject private var state: CommandWindowState
    @State private var inputText = ""
    @State private var showConfirmation = false
    @State private var confirmationMessage = ""
    @State private var window: NSWindow?
    @State private var hasFocusedCurrentPresentation = false
    @State private var hasAppliedInitialFocusDelay = false
    @FocusState private var isInputFocused: Bool

    @State private var selectedDuration: TimeInterval? = nil
    @State private var showTimePicker = false
    @StateObject private var recentStore = RecentTimesStore()
    @State private var isHoveringClock = false

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
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Color.accentColor)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                } else {
                    HStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28, weight: .ultraLight, design: .rounded))
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                        
                        TextField("Remind me to... @5m", text: $inputText)
                            .font(.system(size: 28, weight: .ultraLight, design: .rounded))
                            .textFieldStyle(.plain)
                            .focused($isInputFocused)
                            .onSubmit {
                                submitTask()
                            }
                        
                        if let duration = selectedDuration {
                            TimeChip(duration: duration) {
                                withAnimation { selectedDuration = nil }
                            }
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                        }
                        
                        if inputText.isEmpty && selectedDuration == nil {
                            // Keyboard shortcut hint
                            HStack(spacing: 4) {
                                let parts = state.shortcutHint.split(separator: " ")
                                ForEach(0..<parts.count, id: \.self) { i in
                                    Text(String(parts[i]))
                                }
                            }
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(6)
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
            let duration = selectedDuration
            onSubmit(text, duration)
            if let d = duration { recentStore.add(d) }
            
            withAnimation(.easeIn(duration: 0.15)) {
                confirmationMessage = "Saved: \(text)"
                showConfirmation = true
                if showTimePicker { togglePicker() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onEscape()
                inputText = ""
                selectedDuration = nil
                showConfirmation = false
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
