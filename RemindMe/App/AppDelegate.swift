import AppKit
import ServiceManagement

@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    public var taskStore: TaskStore!
    public var menuBarController: MenuBarController!
    public var commandWindowController: CommandWindowController!
    public var popupManager: PopupManager!
    public var hotkeyManager: HotkeyManager!
    public var lockOverlayController: LockOverlayController!
    public var caffeinateManager: CaffeinateManager!
    public var batteryManager: BatteryManager!
    
    private var taskTimer: Timer?
    private var lastAlertedBatteryPercentage: Int?
    private var lastUsedNotificationStyle: Bool = false
    private var lastUsedThreshold: Int = 10
    
    // Default to popup style unless user sets to true in settings
    private var useSystemNotifications: Bool {
        UserDefaults.standard.bool(forKey: "useSystemNotifications")
    }
    
    private var enableLowBatteryAlert: Bool {
        UserDefaults.standard.bool(forKey: "enableLowBatteryAlert")
    }
    
    private var lowBatteryThreshold: Int {
        let val = UserDefaults.standard.integer(forKey: "lowBatteryThreshold")
        return val == 0 ? 10 : val
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Match Buffer: set activation policy programmatically so the app
        // can properly activate and receive keyboard events in its windows.
        NSApp.setActivationPolicy(.accessory)
        
        taskStore = TaskStore()
        popupManager = PopupManager(taskStore: taskStore)
        caffeinateManager = CaffeinateManager()
        menuBarController = MenuBarController(taskStore: taskStore, caffeinateManager: caffeinateManager)
        commandWindowController = CommandWindowController()
        hotkeyManager = HotkeyManager()
        lockOverlayController = LockOverlayController()
        
        commandWindowController.onParseText = { [weak self] text, duration in
            self?.handleCommand(text, duration: duration)
        }
        
        commandWindowController.onLockCommand = { [weak self] duration in
            self?.lockOverlayController.show(duration: duration)
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
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowCommandWindowWithLock"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.menuBarController.closePopover(nil)
                self?.commandWindowController.showWindow(prefillText: "lock @30s")
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

        batteryManager = BatteryManager()
        setupBatteryMonitoring()
        startTaskTimer()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        caffeinateManager.stop()
        hotkeyManager.unregister()
        batteryManager.stopMonitoring()
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
    
    private func setupBatteryMonitoring() {
        lastUsedNotificationStyle = useSystemNotifications
        lastUsedThreshold = lowBatteryThreshold
        
        batteryManager.onBatteryStateChanged = { [weak self] state in
            self?.handleBatteryStateChange(state)
        }
        batteryManager.startMonitoring()
        
        // Listen for settings change via user defaults
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let currentStyle = self.useSystemNotifications
                let currentThreshold = self.lowBatteryThreshold
                if currentStyle != self.lastUsedNotificationStyle || currentThreshold != self.lastUsedThreshold {
                    self.lastUsedNotificationStyle = currentStyle
                    self.lastUsedThreshold = currentThreshold
                    self.lastAlertedBatteryPercentage = nil
                }
                self.evaluateBatteryState()
            }
        }
    }
    
    private func evaluateBatteryState() {
        guard let state = batteryManager.currentState else { return }
        handleBatteryStateChange(state)
    }
    
    private func handleBatteryStateChange(_ state: BatteryState) {
        guard enableLowBatteryAlert else {
            dismissBatteryAlerts()
            lastAlertedBatteryPercentage = nil
            return
        }
        
        if state.isConnectedToPower || state.isCharging {
            dismissBatteryAlerts()
            lastAlertedBatteryPercentage = nil
            return
        }
        
        if state.percentage < lowBatteryThreshold {
            let shouldAlert: Bool
            if let last = lastAlertedBatteryPercentage {
                shouldAlert = state.percentage < last
            } else {
                shouldAlert = true
            }
            
            if shouldAlert {
                lastAlertedBatteryPercentage = state.percentage
                let message = "Battery at \(state.percentage)% — plug in your charger."
                
                if useSystemNotifications {
                    NotificationManager.deliverLowBatteryNotification(message: message)
                    popupManager.dismissBatteryPopup()
                } else {
                    popupManager.showBatteryPopup(message: message)
                    NotificationManager.dismissLowBatteryNotification()
                }
            }
        } else {
            dismissBatteryAlerts()
            lastAlertedBatteryPercentage = nil
        }
    }
    
    private func dismissBatteryAlerts() {
        NotificationManager.dismissLowBatteryNotification()
        popupManager.dismissBatteryPopup()
    }
}
