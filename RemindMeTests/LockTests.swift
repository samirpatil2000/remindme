import XCTest
@testable import RemindMe

@MainActor
final class LockTests: XCTestCase {
    
    var userDefaults: UserDefaults!
    let suiteName = "LockTestsSuite"
    
    override func setUp() async throws {
        try await super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }
    
    override func tearDown() async throws {
        userDefaults.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }
    
    func testBreakStoreIncrement() {
        var store = BreakStore()
        
        // Reset defaults just in case
        userDefaults.removePersistentDomain(forName: suiteName)
        UserDefaults.standard.removeObject(forKey: "RemindMe.BreaksTodayCount")
        UserDefaults.standard.removeObject(forKey: "RemindMe.BreaksTodayDate")
        
        XCTAssertEqual(store.breaksToday, 0)
        
        store.increment()
        XCTAssertEqual(store.breaksToday, 1)
        
        store.increment()
        XCTAssertEqual(store.breaksToday, 2)
    }
    
    func testBreakStoreResetsOnDifferentDate() {
        // Manually write an old date
        UserDefaults.standard.set(5, forKey: "RemindMe.BreaksTodayCount")
        UserDefaults.standard.set("2020-01-01", forKey: "RemindMe.BreaksTodayDate")
        
        var store = BreakStore()
        XCTAssertEqual(store.breaksToday, 0) // Should reset to 0 since date is old
        
        store.increment()
        XCTAssertEqual(store.breaksToday, 1) // Should start counting from 1 today
    }
    
    func testCaffeinateManagerStartStop() async throws {
        let manager = CaffeinateManager()
        
        XCTAssertFalse(manager.isActive)
        XCTAssertNil(manager.expiresAt)
        
        manager.start(duration: 5)
        XCTAssertTrue(manager.isActive)
        XCTAssertNotNil(manager.expiresAt)
        
        manager.stop()
        XCTAssertFalse(manager.isActive)
        XCTAssertNil(manager.expiresAt)
    }

    func testCaffeinateManagerToggles() async throws {
        let manager = CaffeinateManager()
        
        XCTAssertTrue(manager.keepDisplayAwake)
        XCTAssertFalse(manager.keepAwakeOnLidClose)
        
        manager.keepDisplayAwake = false
        XCTAssertFalse(manager.keepDisplayAwake)
        
        manager.keepAwakeOnLidClose = true
        XCTAssertTrue(manager.keepAwakeOnLidClose)
    }
}
