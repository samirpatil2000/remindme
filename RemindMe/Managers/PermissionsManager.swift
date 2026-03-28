import AppKit

@MainActor
public class PermissionsManager {
    public static func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }
    
    public static func requestAccessibility() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
