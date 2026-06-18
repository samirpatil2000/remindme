import AppKit
import SwiftUI

public class LockOverlayPanel: NSPanel {
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}

@MainActor
public final class LockOverlayController: NSObject {
    private var panels: [LockOverlayPanel] = []
    private var localEventMonitor: Any?
    private var breakStore = BreakStore()
    
    public var onDismiss: (() -> Void)?
    
    // Rotating calm message index in-memory (not persisted)
    private static var messageIndex = 0
    
    private let calmMessages = [
        "Take a deep breath.",
        "Relax your shoulders.",
        "Rest your eyes.",
        "Stretch your arms.",
        "Look at something far away.",
        "Clear your mind.",
        "Release any tension.",
        "Enjoy this quiet moment.",
        "Inhale peace, exhale stress.",
        "You are doing great."
    ]
    
    public override init() {
        super.init()
    }
    
    public func show(duration: TimeInterval) {
        // Dismiss any existing overlays first
        dismiss(incrementBreak: false)
        
        let message = calmMessages[Self.messageIndex]
        Self.messageIndex = (Self.messageIndex + 1) % calmMessages.count
        
        let breaksCount = breakStore.breaksToday
        
        for screen in NSScreen.screens {
            let panel = LockOverlayPanel(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.backgroundColor = .black
            panel.isOpaque = true
            panel.hasShadow = false
            
            let swiftUIView = LockOverlayView(
                duration: duration,
                calmMessage: message,
                breaksToday: breaksCount,
                onComplete: { [weak self] in
                    self?.dismiss(incrementBreak: true)
                },
                onEscape: { [weak self] in
                    self?.dismiss(incrementBreak: false)
                }
            )
            
            let hostingView = NSHostingView(rootView: swiftUIView)
            panel.contentView = hostingView
            
            panel.alphaValue = 1.0
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        
        // Key monitor: capture Escape (53) key events while overlay is visible
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                NotificationCenter.default.post(name: NSNotification.Name("LockOverlayEscapePressed"), object: nil)
                return nil // consume the event
            }
            return event
        }
        
        // Activate app to ensure key events can be captured by our local monitor
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func dismiss() {
        dismiss(incrementBreak: false)
    }
    
    private func dismiss(incrementBreak: Bool) {
        guard !panels.isEmpty else { return }
        
        if incrementBreak {
            breakStore.increment()
        }
        
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        let currentPanels = panels
        panels.removeAll()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            for panel in currentPanels {
                panel.animator().alphaValue = 0.0
            }
        }) {
            Task { @MainActor in
                for panel in currentPanels {
                    panel.orderOut(nil)
                }
                self.onDismiss?()
                NotificationCenter.default.post(name: NSNotification.Name("LockOverlayDismissed"), object: nil)
            }
        }
    }
}
