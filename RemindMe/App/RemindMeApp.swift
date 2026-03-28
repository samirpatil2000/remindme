import SwiftUI

@main
struct RemindMeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("globalShortcutData") private var shortcutData: Data = Data()
    
    var body: some Scene {
        Settings {
            SettingsView(shortcut: Binding(get: {
                if let decoded = try? JSONDecoder().decode(Shortcut.self, from: shortcutData) {
                    return decoded
                }
                return .defaultShortcut
            }, set: { newShortcut in
                if let encoded = try? JSONEncoder().encode(newShortcut) {
                    shortcutData = encoded
                    appDelegate.updateHotkey(shortcut: newShortcut)
                }
            }))
        }
    }
}
