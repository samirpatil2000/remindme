import AppKit
import SwiftUI

@MainActor
public class MenuBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var taskStore: TaskStore
    
    public init(taskStore: TaskStore) {
        self.taskStore = taskStore
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let icon = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: "RemindMe")
            icon?.isTemplate = true
            button.image = icon
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: StatusBoardView(taskStore: taskStore))
        
        statusItem.button?.target = self
    }
    
    @objc private func showCommandWindowFromMenu() {
        NotificationCenter.default.post(name: NSNotification.Name("ShowCommandWindow"), object: nil)
    }

    @objc private func openSettingsFromMenu() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            let menu = NSMenu()
            menu.addItem(withTitle: "New Reminder", action: #selector(showCommandWindowFromMenu), keyEquivalent: "n")
            menu.items.last?.target = self
            menu.addItem(withTitle: "Settings...", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
            menu.items.last?.target = self
            menu.addItem(NSMenuItem.separator())
            menu.addItem(withTitle: "Quit RemindMe", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
            return
        }
        
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
