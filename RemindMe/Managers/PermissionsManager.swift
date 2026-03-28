import AppKit

public class PermissionsManager {
    public static func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }
    
    public static func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }
}
