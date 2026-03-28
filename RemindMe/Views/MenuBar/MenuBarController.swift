import AppKit
import SwiftUI

public class MenuBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var taskStore: TaskStore
    
    public init(taskStore: TaskStore) {
        self.taskStore = taskStore
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: "RemindMe")
            button.action = #selector(togglePopover(_:))
        }
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: StatusBoardView(taskStore: taskStore))
        
        statusItem.button?.target = self
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    public func showPopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    public func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }
}
