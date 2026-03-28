import Foundation
import UserNotifications

public class NotificationManager {
    public static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    public static func deliverSystemNotification(for task: ReminderTask) {
        let content = UNMutableNotificationContent()
        content.title = "Reminder fired"
        content.body = task.title
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
