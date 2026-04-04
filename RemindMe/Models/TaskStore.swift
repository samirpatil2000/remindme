import Foundation
import Combine

public class TaskStore: ObservableObject {
    @Published public private(set) var tasks: [ReminderTask] = []
    
    private let userDefaultsKey = "RemindMe.TaskStore.tasks"
    private let defaults: UserDefaults
    public var now: () -> Date
    
    public init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        load()
        checkMissedRemindersOnLaunch()
    }
    
    public var activeTasks: [ReminderTask] {
        tasks.filter { $0.state == .active || $0.state == .stillRunning }
    }
    
    public var pastDueTasks: [ReminderTask] {
        tasks.filter { $0.state == .pastDue }
    }
    
    public var completedToday: Int {
        let currentDate = now()
        let calendar = Calendar.current
        return tasks.filter { task in
            task.state == .done && calendar.isDate(task.createdAt, inSameDayAs: currentDate)
        }.count
    }
    
    public func add(task: ReminderTask) {
        tasks.append(task)
        save()
    }
    
    public func markDone(id: UUID) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].state = .done
            tasks[index].completedAt = now()
            save()
        }
    }
    
    public func markStillRunning(id: UUID, newFiresAt: Date) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            let oldFiresAt = tasks[index].reminderFiresAt
            let delayDiff = newFiresAt.timeIntervalSince(oldFiresAt)
            let addedDelay = max(0, delayDiff)
            
            tasks[index].state = .stillRunning
            tasks[index].reminderFiresAt = newFiresAt
            tasks[index].reminderFired = false
            tasks[index].reminderFiredAt = nil
            tasks[index].snoozeCount += 1
            tasks[index].totalSnoozeDelay += addedDelay
            save()
        }
    }
    
    public func delete(id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }
    
    // Function that changes active to pastDue when a popup is dismissed without action
    public func markPastDue(id: UUID) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].state = .pastDue
            save()
        }
    }
    
    // System calls this when popups are shown
    public func markFired(id: UUID) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].reminderFired = true
            tasks[index].reminderFiredAt = now()
            save()
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            defaults.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func load() {
        if let data = defaults.data(forKey: userDefaultsKey) {
            do {
                let decoded = try JSONDecoder().decode([ReminderTask].self, from: data)
                self.tasks = decoded
            } catch {
                print("Schema change detected or corrupt data. Erasing previous TaskStore.")
                self.tasks = []
                save()
            }
        }
    }
    
    private func checkMissedRemindersOnLaunch() {
        // If a task fired, but wasn't marked done, check its state.
        // The popup manager will eventually hook in to schedule Notifications.
    }
}
