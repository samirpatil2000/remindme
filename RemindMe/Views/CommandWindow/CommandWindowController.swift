import AppKit
import SwiftUI

public class CommandPanel: NSPanel {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    
    public override func cancelOperation(_ sender: Any?) {
        (self.windowController as? CommandWindowController)?.hideWindow()
    }
}

public class CommandWindowController: NSWindowController, NSWindowDelegate {
    public var onParseText: ((String) -> Void)?
    
    private var isAnimating = false
    
    public init() {
        let panel = CommandPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 80),
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
        visualEffect.material = .popover
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true
        
        panel.contentView = visualEffect
        
        let swiftUIView = CommandWindowView { [weak self] text in
            self?.onParseText?(text)
        } onEscape: { [weak self] in
            self?.hideWindow()
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
        
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        isAnimating = true
        window.alphaValue = 0
        window.contentView?.layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
            window.contentView?.animator().layer?.transform = CATransform3DIdentity
        }) {
            self.isAnimating = false
        }
    }
    
    public func hideWindow() {
        guard let window = self.window, !isAnimating else { return }
        if window.alphaValue == 0 { return }
        
        isAnimating = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0.0
            window.contentView?.animator().layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
        }) {
            window.orderOut(nil)
            self.isAnimating = false
        }
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        hideWindow()
    }
}
