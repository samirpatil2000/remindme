import AppKit
import SwiftUI

@MainActor
public final class CommandWindowState: ObservableObject {
    @Published public var shortcutHint: String
    @Published public private(set) var focusRequestID = UUID()

    public init(shortcutHint: String = "⌘ ⇧ Space") {
        self.shortcutHint = shortcutHint
    }

    public func requestFocus() {
        focusRequestID = UUID()
    }
}

public class CommandPanel: NSPanel {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    
    public override func cancelOperation(_ sender: Any?) {
        (self.windowController as? CommandWindowController)?.hideWindow()
    }
}

public class CommandWindowController: NSWindowController, NSWindowDelegate {
    public var onParseText: ((String, TimeInterval?) -> Void)?
    
    private var isAnimating = false
    private let state = CommandWindowState()
    
    public init() {
        let panel = CommandPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 72),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        
        super.init(window: panel)
        panel.windowController = self
        
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 14
        visualEffect.layer?.masksToBounds = true
        
        panel.contentView = visualEffect
        
        let swiftUIView = CommandWindowView(state: state) { [weak self] text, duration in
            self?.onParseText?(text, duration)
        } onEscape: { [weak self] in
            self?.hideWindow()
        } onTogglePicker: { [weak self] showPicker in
            self?.resizePanel(to: showPicker ? 220 : 72)
        }
        
        let hostingView = NSHostingView(rootView: swiftUIView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor)
        ])
        
        panel.delegate = self
        panel.center()
        panel.alphaValue = 0 // start invisible
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func showWindow() {
        guard let window = self.window, !isAnimating else { return }

        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - (560 / 2)
            // Golden ratio-ish: position slightly above center — start 14pt below and drift up
            let y = screen.visibleFrame.midY + (screen.visibleFrame.height * 0.15)
            window.setFrame(NSRect(x: x, y: y - 14, width: 560, height: 72), display: false)
        } else {
            window.center()
        }

        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
        state.requestFocus()

        isAnimating = true
        window.alphaValue = 0

        // Spring bloom: scale 0.92 → 1.0 with natural overshoot (liquid expansion feel)
        if let layer = window.contentView?.layer {
            layer.transform = CATransform3DIdentity  // model layer = final state
            let springAnim = CASpringAnimation(keyPath: "transform")
            springAnim.fromValue = CATransform3DMakeScale(0.92, 0.92, 1.0)
            springAnim.toValue = CATransform3DIdentity
            springAnim.mass = 1.0
            springAnim.stiffness = 320
            springAnim.damping = 18
            springAnim.initialVelocity = 1.5
            springAnim.duration = springAnim.settlingDuration
            layer.add(springAnim, forKey: "bloomIn")
        }

        // Fade in + drift up 14pt with easeOut
        var targetFrame = window.frame
        targetFrame.origin.y += 14

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
            window.animator().setFrame(targetFrame, display: false)
        }) {
            Task { @MainActor in
                self.isAnimating = false
            }
        }
    }
    
    public func hideWindow() {
        guard let window = self.window, !isAnimating else { return }
        if window.alphaValue == 0 { return }

        isAnimating = true

        // Drift upward slightly while scaling down and fading — feels like the window lifts away
        var frame = window.frame
        frame.origin.y += 8

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 1.0, 1.0)
            window.animator().alphaValue = 0.0
            window.animator().setFrame(frame, display: false)
            window.contentView?.animator().layer?.transform = CATransform3DMakeScale(0.97, 0.97, 1.0)
        }) {
            Task { @MainActor in
                window.orderOut(nil)
                // Reset transform for next show
                window.contentView?.layer?.transform = CATransform3DIdentity
                self.isAnimating = false
            }
        }
    }
    
    private var localEventMonitor: Any?

    public func windowDidResignKey(_ notification: Notification) {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        hideWindow()
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        state.requestFocus()
        
        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 48 { // Tab
                    NotificationCenter.default.post(name: NSNotification.Name("CommandWindowTabPressed"), object: nil)
                    return nil
                }
                return event
            }
        }
    }
    
    public func resizePanel(to newHeight: CGFloat) {
        guard let window = self.window else { return }
        var currentFrame = window.frame
        let heightDiff = newHeight - currentFrame.height
        currentFrame.origin.y -= heightDiff
        currentFrame.size.height = newHeight
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
            window.animator().setFrame(currentFrame, display: true)
        }
    }
    
    public func updateShortcutHint(with shortcut: Shortcut) {
        state.shortcutHint = shortcutString(from: shortcut)
    }
    
    public func shortcutString(from shortcut: Shortcut) -> String {
        return shortcut.displayString
    }
}
