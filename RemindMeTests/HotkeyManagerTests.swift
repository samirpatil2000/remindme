import XCTest
@testable import RemindMe

final class HotkeyManagerTests: XCTestCase {
    
    func testRegistrationSucceedsSilently() {
        let manager = HotkeyManager()
        // In unit test environment, accessibility is not granted, 
        // global monitor will silently fail or not trigger, which matches spec.
        manager.register()
        XCTAssertEqual(manager.currentShortcut, .defaultShortcut)
        manager.unregister()
    }
    
    func testChangeHotkey() {
        let manager = HotkeyManager()
        let newShortcut = Shortcut(keyCode: 0, modifiers: 0) // 'A' key, no mod
        manager.register(shortcut: newShortcut)
        XCTAssertEqual(manager.currentShortcut, newShortcut)
    }
}
