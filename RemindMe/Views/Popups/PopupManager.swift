import AppKit
import SwiftUI
import Combine

@MainActor
public class ActivePopup: Identifiable {
    public let id: UUID
    public let task: ReminderTask
    public var panel: NSPanel?

    public init(task: ReminderTask, panel: NSPanel? = nil) {
        self.id = task.id
        self.task = task
        self.panel = panel
    }
}

public enum PopupAction {
    case done
    case snooze(Int)
    case stillRunning
}

@MainActor
public class PopupManager: ObservableObject {
    @Published public private(set) var visiblePopups: [ActivePopup] = []
    @Published public private(set) var overflowPopups: [ActivePopup] = []
    
    public var moreIndicatorPanel: NSPanel?
    
    private let taskStore: TaskStore
    public var onOpenMenuBar: (() -> Void)?
    
    private let maxVisible = 3
    private let cardWidth: CGFloat = 360
    private let cardHeight: CGFloat = 160
    private let stackGap: CGFloat = 8
    private let screenEdgePadding: CGFloat = 16
    
    public init(taskStore: TaskStore) {
        self.taskStore = taskStore
    }
    
    public func showPopup(for task: ReminderTask) {
        let newPopup = ActivePopup(task: task)
        
        if visiblePopups.count < maxVisible {
            visiblePopups.append(newPopup)
            createAndShowPanel(for: newPopup)
            layoutPanels()
        } else {
            overflowPopups.append(newPopup)
            updateMoreIndicator()
        }
        
        taskStore.markFired(id: task.id)
    }
    
    public func dismissPopup(taskID: UUID, withoutAction: Bool = false) {
        if withoutAction {
            taskStore.markPastDue(id: taskID)
        }
        
        if let index = visiblePopups.firstIndex(where: { $0.id == taskID }) {
            let removed = visiblePopups.remove(at: index)
            animateDismiss(panel: removed.panel) {
                removed.panel?.close()
                removed.panel = nil
            }
            
            if !overflowPopups.isEmpty {
                let next = overflowPopups.removeFirst()
                visiblePopups.append(next)
                createAndShowPanel(for: next)
            }
            layoutPanels()
            
        } else if let index = overflowPopups.firstIndex(where: { $0.id == taskID }) {
            overflowPopups.remove(at: index)
            updateMoreIndicator()
        }
    }
    
    public func handleAction(_ action: PopupAction, for taskID: UUID) {
        switch action {
        case .done:
            taskStore.markDone(id: taskID)
        case .snooze(let minutes):
            let newDate = taskStore.now().addingTimeInterval(TimeInterval(minutes * 60))
            taskStore.markStillRunning(id: taskID, newFiresAt: newDate)
        case .stillRunning:
            let defaultDuration: TimeInterval = 600
            taskStore.markStillRunning(id: taskID, newFiresAt: taskStore.now().addingTimeInterval(defaultDuration))
        }
        dismissPopup(taskID: taskID, withoutAction: false)
    }
    
    public func openMenuBar() {
        onOpenMenuBar?()
    }
    
    // MARK: - Panel Creation & Display
    
    private func createAndShowPanel(for popup: ActivePopup) {
        let taskID = popup.task.id
        let taskTitle = popup.task.title
        
        let cardView = PopupStackView(
            title: taskTitle,
            onDone: { [weak self] in
                self?.handleAction(.done, for: taskID)
            },
            onSnooze: { [weak self] mins in
                self?.handleAction(.snooze(mins), for: taskID)
            },
            onStillRunning: { [weak self] in
                self?.handleAction(.stillRunning, for: taskID)
            }
        )
        
        let panel = PopupCard(view: cardView)
        popup.panel = panel
        
        // Position at center of screen, start slightly scaled down
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let centerX = screenFrame.maxX - cardWidth - screenEdgePadding
        let centerY = screenFrame.minY + screenEdgePadding
        
        panel.setFrame(NSRect(x: centerX, y: centerY, width: cardWidth, height: cardHeight), display: true)
        panel.alphaValue = 0
        panel.contentView?.layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
        panel.orderFrontRegardless()
        
        // Animate scale up + fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
            panel.contentView?.animator().layer?.transform = CATransform3DIdentity
        }
    }
    
    // MARK: - Layout
    
    private func layoutPanels() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        // Calculate total stack height to center the group vertically
        let totalCards = CGFloat(visiblePopups.count)
        let totalHeight = totalCards * cardHeight + (totalCards - 1) * stackGap
        let startY = screenFrame.minY + screenEdgePadding + totalHeight
        
        for (index, popup) in visiblePopups.enumerated() {
            guard let panel = popup.panel else { continue }
            
            let targetX = screenFrame.maxX - cardWidth - screenEdgePadding
            let targetY = startY - CGFloat(index + 1) * cardHeight - CGFloat(index) * stackGap
            let targetFrame = NSRect(x: targetX, y: targetY, width: cardWidth, height: cardHeight)
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(targetFrame, display: true)
            }
        }
        
        updateMoreIndicator()
    }
    
    // MARK: - Dismiss Animation
    
    private func animateDismiss(panel: NSPanel?, completion: @escaping @MainActor () -> Void) {
        guard let panel = panel else {
            completion()
            return
        }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.contentView?.animator().layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
        }) {
            Task { @MainActor in
                completion()
            }
        }
    }
    
    // MARK: - Overflow Indicator
    
    private func updateMoreIndicator() {
        if overflowPopups.isEmpty {
            moreIndicatorPanel?.close()
            moreIndicatorPanel = nil
        } else {
            showMoreIndicator()
        }
    }
    
    private func showMoreIndicator() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        let count = overflowPopups.count
        let indicatorHeight: CGFloat = 40
        
        let view = MoreIndicatorView(count: count) { [weak self] in
            self?.openMenuBar()
        }
        
        if moreIndicatorPanel == nil {
            let panel = PopupCard(view: view)
            panel.setFrame(
                NSRect(
                    x: screenFrame.maxX - cardWidth - screenEdgePadding,
                    y: screenFrame.maxY - (CGFloat(maxVisible + 1) * (cardHeight + stackGap)),
                    width: cardWidth,
                    height: indicatorHeight
                ),
                display: true
            )
            panel.orderFrontRegardless()
            moreIndicatorPanel = panel
        }
    }
}
