import XCTest
@testable import RemindMe

final class TaskStoreTests: XCTestCase {
    
    var store: TaskStore!
    var userDefaults: UserDefaults!
    let suiteName = "TaskStoreTestsSuite"
    
    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        store = TaskStore(defaults: userDefaults)
    }
    
    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }
    
    func testAddTaskAppearsInActive() {
        let task = ReminderTask(title: "Test", reminderFiresAt: Date().addingTimeInterval(600))
        store.add(task: task)
        XCTAssertEqual(store.activeTasks.count, 1)
        XCTAssertEqual(store.activeTasks.first?.id, task.id)
    }
    
    func testMarkDoneTaskMovesOutOfActive() {
        let task = ReminderTask(title: "Test", reminderFiresAt: Date().addingTimeInterval(600))
        store.add(task: task)
        store.markDone(id: task.id)
        XCTAssertEqual(store.activeTasks.count, 0)
        XCTAssertEqual(store.tasks.first?.state, .done)
    }
    
    func testMarkStillRunningStaysInActive() {
        let task = ReminderTask(title: "Test", reminderFiresAt: Date())
        store.add(task: task)
        store.markStillRunning(id: task.id, newFiresAt: Date().addingTimeInterval(300))
        XCTAssertEqual(store.activeTasks.count, 1)
        XCTAssertEqual(store.activeTasks.first?.state, .stillRunning)
    }
    
    func testDeleteTask() {
        let task = ReminderTask(title: "Test", reminderFiresAt: Date())
        store.add(task: task)
        XCTAssertEqual(store.tasks.count, 1)
        store.delete(id: task.id)
        XCTAssertEqual(store.tasks.count, 0)
    }
    
    func testCompletedTodayIncrements() {
        let task = ReminderTask(title: "Test", reminderFiresAt: Date())
        store.add(task: task)
        XCTAssertEqual(store.completedToday, 0)
        store.markDone(id: task.id)
        XCTAssertEqual(store.completedToday, 1)
        
        let task2 = ReminderTask(title: "Test 2", reminderFiresAt: Date())
        store.add(task: task2)
        store.markDone(id: task2.id)
        XCTAssertEqual(store.completedToday, 2)
    }
    
    func testCompletedTodayResetsAtMidnight() {
        var currentDate = Date()
        store = TaskStore(defaults: userDefaults, now: { currentDate })
        
        let task = ReminderTask(title: "Test", createdAt: currentDate, reminderFiresAt: currentDate)
        store.add(task: task)
        store.markDone(id: task.id)
        XCTAssertEqual(store.completedToday, 1)
        
        // Move to tomorrow
        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        XCTAssertEqual(store.completedToday, 0)
    }
    
    func testPersistence() {
        let task = ReminderTask(title: "Persisted", reminderFiresAt: Date())
        store.add(task: task)
        
        let store2 = TaskStore(defaults: userDefaults)
        XCTAssertEqual(store2.tasks.count, 1)
        XCTAssertEqual(store2.tasks.first?.title, "Persisted")
    }
    
    func testActiveTasksExcludesDoneAndPastDue() {
        let t1 = ReminderTask(title: "A", reminderFiresAt: Date(), state: .active)
        let t2 = ReminderTask(title: "B", reminderFiresAt: Date(), state: .pastDue)
        let t3 = ReminderTask(title: "C", reminderFiresAt: Date(), state: .done)
        let t4 = ReminderTask(title: "D", reminderFiresAt: Date(), state: .stillRunning)
        
        store.add(task: t1)
        store.add(task: t2)
        store.add(task: t3)
        store.add(task: t4)
        
        XCTAssertEqual(store.activeTasks.count, 2)
        XCTAssertTrue(store.activeTasks.contains { $0.id == t1.id })
        XCTAssertTrue(store.activeTasks.contains { $0.id == t4.id })
    }
    
    func testPastDueTasksOnlyReturnsPastDue() {
        let t1 = ReminderTask(title: "A", reminderFiresAt: Date(), state: .active)
        let t2 = ReminderTask(title: "B", reminderFiresAt: Date(), state: .pastDue)
        
        store.add(task: t1)
        store.add(task: t2)
        
        XCTAssertEqual(store.pastDueTasks.count, 1)
        XCTAssertEqual(store.pastDueTasks.first?.id, t2.id)
    }
}
