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
            let notification = NSUserNotification()
            notification.title = "Reminder fired"
            notification.informativeText = task.title
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
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
