import AppKit
import ServiceManagement

@MainActor
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
        // Match Buffer: set activation policy programmatically so the app
        // can properly activate and receive keyboard events in its windows.
        NSApp.setActivationPolicy(.accessory)
        
        taskStore = TaskStore()
        popupManager = PopupManager(taskStore: taskStore)
        menuBarController = MenuBarController(taskStore: taskStore)
        commandWindowController = CommandWindowController()
        hotkeyManager = HotkeyManager()
        
        commandWindowController.onParseText = { [weak self] text, duration in
            self?.handleCommand(text, duration: duration)
        }
        
        popupManager.onOpenMenuBar = { [weak self] in
            self?.menuBarController.showPopover(nil)
        }
        
        // Wire up hotkey callback
        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.commandWindowController.showWindow()
        }
        
        // Register the saved shortcut on launch.
        if let data = UserDefaults.standard.data(forKey: "globalShortcutData"),
           let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) {
            updateHotkey(shortcut: shortcut)
        } else {
            updateHotkey(shortcut: .defaultShortcut)
        }
        
        // Listen for hotkey changes from Settings
        NotificationCenter.default.addObserver(forName: .hotkeyChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                if let data = UserDefaults.standard.data(forKey: "globalShortcutData"),
                   let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) {
                    self?.updateHotkey(shortcut: shortcut)
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowCommandWindow"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.menuBarController.closePopover(nil)
                self?.commandWindowController.showWindow()
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ClosePopoverOnly"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.menuBarController.closePopover(nil)
            }
        }

        // Temporarily unregister the hotkey while the ShortcutRecorder is capturing
        NotificationCenter.default.addObserver(forName: NSNotification.Name("HotkeyRecordingBegan"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hotkeyManager.unregister()
            }
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("HotkeyRecordingEnded"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hotkeyManager.reregister()
            }
        }
        
        // Auto-register for launch at login on first run
        if !UserDefaults.standard.bool(forKey: "launchAtLoginPrompted") {
            UserDefaults.standard.set(true, forKey: "launchAtLoginPrompted")
            try? SMAppService.mainApp.register()
        }

        startTaskTimer()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
    }
    
    public func updateHotkey(shortcut: Shortcut) {
        hotkeyManager.register(shortcut: shortcut)
        commandWindowController.updateShortcutHint(with: shortcut)
    }
    
    private func handleCommand(_ text: String, duration: TimeInterval? = nil) {
        if let explicitDuration = duration {
            let parsedTitle = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !parsedTitle.isEmpty {
                let fireDate = taskStore.now().addingTimeInterval(explicitDuration)
                let task = ReminderTask(title: parsedTitle, reminderFiresAt: fireDate)
                taskStore.add(task: task)
            }
            return
        }
        
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
            Task { @MainActor [weak self] in
                self?.checkTasks()
            }
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
