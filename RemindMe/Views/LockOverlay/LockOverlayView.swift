import SwiftUI

public struct LockOverlayView: View {
    let duration: TimeInterval
    let calmMessage: String
    let breaksToday: Int
    let onComplete: () -> Void
    let onEscape: () -> Void
    
    @State private var escPressedOnce = false
    @State private var escTimerTask: Task<Void, Never>? = nil
    
    private let startDate = Date()
    
    // Deterministic static fractional positions for 10 dots
    private struct DotPosition: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
    }
    
    private let dotPositions = [
        DotPosition(x: 0.15, y: 0.20),
        DotPosition(x: 0.82, y: 0.15),
        DotPosition(x: 0.25, y: 0.78),
        DotPosition(x: 0.72, y: 0.85),
        DotPosition(x: 0.10, y: 0.52),
        DotPosition(x: 0.90, y: 0.48),
        DotPosition(x: 0.35, y: 0.28),
        DotPosition(x: 0.65, y: 0.22),
        DotPosition(x: 0.40, y: 0.70),
        DotPosition(x: 0.58, y: 0.75)
    ]
    
    public init(
        duration: TimeInterval,
        calmMessage: String,
        breaksToday: Int,
        onComplete: @escaping () -> Void,
        onEscape: @escaping () -> Void
    ) {
        self.duration = duration
        self.calmMessage = calmMessage
        self.breaksToday = breaksToday
        self.onComplete = onComplete
        self.onEscape = onEscape
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                // Static dots scattered across the screen
                ForEach(dotPositions) { dot in
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 4, height: 4)
                        .position(x: dot.x * geometry.size.width, y: dot.y * geometry.size.height)
                }
                
                // Main Content View
                TimelineView(.periodic(from: startDate, by: 1.0)) { context in
                    let elapsed = context.date.timeIntervalSince(startDate)
                    let remaining = max(0, duration - elapsed)
                    let progress = remaining / duration
                    let secondsInt = Int(ceil(remaining))
                    
                    VStack(spacing: 48) {
                        // Circular countdown ring
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 4)
                                .frame(width: 120, height: 120)
                            
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1.0), value: progress)
                            
                            Text("\(secondsInt)")
                                .font(.system(size: 36, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        // Messages group
                        VStack(spacing: 16) {
                            Text(calmMessage)
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 600)
                            
                            Text("\(breaksToday) breaks today")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: secondsInt) { _, newValue in
                        if newValue <= 0 {
                            onComplete()
                        }
                    }
                }
                
                // Permanent exit hint
                VStack {
                    Spacer()
                    Text("Press Esc twice to exit")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.bottom, 24)
                }

                // Escape Hint View
                if escPressedOnce {
                    VStack {
                        Spacer()
                        Text("Press Esc again to skip")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(18)
                            .padding(.bottom, 60)
                            .transition(.opacity)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LockOverlayEscapePressed"))) { _ in
            handleEscapePress()
        }
    }
    
    private func handleEscapePress() {
        if escPressedOnce {
            // Second Escape: dismiss without break increment
            escTimerTask?.cancel()
            onEscape()
        } else {
            // First Escape: show hint and set a 2-second timeout
            withAnimation(.easeIn(duration: 0.2)) {
                escPressedOnce = true
            }
            escTimerTask?.cancel()
            escTimerTask = Task {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    escPressedOnce = false
                }
            }
        }
    }
}
