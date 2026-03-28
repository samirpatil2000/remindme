import Foundation
import UserNotifications

public class NotificationManager {
    public static func requestAuthorization() {
        if Bundle.main.bundleIdentifier == nil {
            print("Cannot request UNUserNotificationCenter authorization without a bundle identifier.")
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    public static func deliverSystemNotification(for task: ReminderTask) {
        if Bundle.main.bundleIdentifier == nil {
            // Fallback for raw executable / testing context
            let safeTitle = task.title.replacingOccurrences(of: "\"", with: "\\\"")
            let script = "display notification \"\(safeTitle)\" with title \"Reminder fired\" sound name \"Submarine\""
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
                if let error = error {
                    print("AppleScript notification error: \(error)")
                }
            }
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Reminder fired"
        content.body = task.title
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
