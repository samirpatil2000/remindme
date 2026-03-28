import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate {
    public var taskStore: TaskStore!
    public var menuBarController: MenuBarController!
    public var commandWindowController: CommandWindowController!
    public var popupManager: PopupManager!
    public var hotkeyManager: HotkeyManager!
    
    private var taskTimer: Timer?
    
    // Default to popup style unless user sets to true in settings
    private var useSystemNotifications: Bool {
        UserDefaults.standard.bool(forKey: "useSystemNotifications")
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        taskStore = TaskStore()
        popupManager = PopupManager(taskStore: taskStore)
        menuBarController = MenuBarController(taskStore: taskStore)
        commandWindowController = CommandWindowController()
        hotkeyManager = HotkeyManager()
        
        commandWindowController.onParseText = { [weak self] text in
            self?.handleCommand(text)
        }
        
        popupManager.onOpenMenuBar = { [weak self] in
            self?.menuBarController.showPopover(nil)
        }
        
        if PermissionsManager.isAccessibilityGranted() {
            if let data = UserDefaults.standard.data(forKey: "globalShortcutData"),
               let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) {
                updateHotkey(shortcut: shortcut)
            } else {
                updateHotkey(shortcut: .defaultShortcut)
            }
        }
        
        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.commandWindowController.showWindow()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowCommandWindow"), object: nil, queue: .main) { [weak self] _ in
            self?.menuBarController.closePopover(nil)
            self?.commandWindowController.showWindow()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowSettingsWindow"), object: nil, queue: .main) { [weak self] _ in
            self?.menuBarController.closePopover(nil)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ClosePopoverOnly"), object: nil, queue: .main) { [weak self] _ in
            self?.menuBarController.closePopover(nil)
        }
        
        startTaskTimer()
    }
    
    public func updateHotkey(shortcut: Shortcut) {
        hotkeyManager.register(shortcut: shortcut)
        commandWindowController.updateShortcutHint(with: shortcut)
    }
    
    private func handleCommand(_ text: String) {
        let result = ReminderParser.parse(text)
        switch result {
        case .success(let payload):
            let task = ReminderTask(title: payload.title, reminderFiresAt: payload.firesAt)
            taskStore.add(task: task)
        case .failure:
            break
        }
    }
    
    private func startTaskTimer() {
        taskTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkTasks()
        }
    }
    
    private func checkTasks() {
        let now = taskStore.now()
        let firingTasks = taskStore.activeTasks.filter { $0.reminderFiresAt <= now && !$0.reminderFired }
        
        for task in firingTasks {
            if useSystemNotifications {
                NotificationManager.deliverSystemNotification(for: task)
                taskStore.markFired(id: task.id)
                taskStore.markPastDue(id: task.id)
            } else {
                popupManager.showPopup(for: task)
            }
        }
    }
}
