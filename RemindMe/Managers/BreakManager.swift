import Foundation
import AppKit

@MainActor
public final class BreakManager: ObservableObject {
    private var timer: Timer?
    private var lastBreakTime = Date()
    private weak var appDelegate: AppDelegate?

    public init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        setupTimer()
        
        // Listen to UserDefault changes to reschedule timer
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.setupTimer()
            }
        }
        
        // Reset last break time whenever a lock overlay is dismissed
        NotificationCenter.default.addObserver(forName: NSNotification.Name("LockOverlayDismissed"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resetBreakTimer()
            }
        }
    }
    
    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "enablePeriodicBreaks")
    }
    
    private var breakInterval: TimeInterval {
        let mins = UserDefaults.standard.integer(forKey: "periodicBreakInterval")
        let interval = mins == 0 ? 25 : mins
        return TimeInterval(interval * 60)
    }
    
    private var breakDuration: TimeInterval {
        let secs = UserDefaults.standard.integer(forKey: "periodicBreakDuration")
        return secs == 0 ? 30 : TimeInterval(secs)
    }
    
    public func setupTimer() {
        timer?.invalidate()
        timer = nil
        
        guard isEnabled else { return }
        
        // Check every 10 seconds to see if a break is due
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkBreak()
            }
        }
    }
    
    private func checkBreak() {
        guard isEnabled, let appDelegate = appDelegate else { return }
        
        let elapsed = Date().timeIntervalSince(lastBreakTime)
        if elapsed >= breakInterval {
            // Check if Command Window is visible before interrupting
            if let cmdWindow = appDelegate.commandWindowController.window, cmdWindow.isVisible {
                return
            }
            
            // Trigger the break!
            appDelegate.lockOverlayController.show(duration: breakDuration)
            lastBreakTime = Date()
        }
    }
    
    public func resetBreakTimer() {
        lastBreakTime = Date()
    }
}
