import XCTest
@testable import RemindMe

final class TaskStateTests: XCTestCase {
    
    func testNewTaskStartsActive() {
        let task = ReminderTask(title: "Test", reminderFiresAt: Date().addingTimeInterval(600))
        XCTAssertEqual(task.state, .active)
    }
    
    func testStateTransitionActiveToPastDue() {
        let store = TaskStore(defaults: UserDefaults(suiteName: "Test-\(UUID())")!)
        var task = ReminderTask(title: "Test", reminderFiresAt: Date().addingTimeInterval(600))
        store.add(task: task)
        store.markPastDue(id: task.id)
        XCTAssertEqual(store.tasks.first?.state, .pastDue)
    }
    
    func testStateTransitionActiveToDone() {
        let store = TaskStore(defaults: UserDefaults(suiteName: "Test-\(UUID())")!)
        var task = ReminderTask(title: "Test", reminderFiresAt: Date().addingTimeInterval(600))
        store.add(task: task)
        store.markDone(id: task.id)
        XCTAssertEqual(store.tasks.first?.state, .done)
    }
    
    func testStateTransitionActiveToStillRunning() {
        let store = TaskStore(defaults: UserDefaults(suiteName: "Test-\(UUID())")!)
        var task = ReminderTask(title: "Test", reminderFiresAt: Date().addingTimeInterval(600))
        store.add(task: task)
        let newDate = Date().addingTimeInterval(1000)
        store.markStillRunning(id: task.id, newFiresAt: newDate)
        XCTAssertEqual(store.tasks.first?.state, .stillRunning)
        XCTAssertEqual(store.tasks.first?.reminderFiresAt, newDate)
    }
    
    func testStateTransitionStillRunningToDone() {
        let store = TaskStore(defaults: UserDefaults(suiteName: "Test-\(UUID())")!)
        var task = ReminderTask(title: "Test", reminderFiresAt: Date().addingTimeInterval(600), state: .stillRunning)
        store.add(task: task)
        store.markDone(id: task.id)
        XCTAssertEqual(store.tasks.first?.state, .done)
    }
}
