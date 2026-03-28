import SwiftUI

public extension Color {
    static let semanticBackground = Color(NSColor.windowBackgroundColor)
    static let semanticLabel = Color(NSColor.labelColor)
    static let semanticSecondaryLabel = Color(NSColor.secondaryLabelColor)
    static let semanticAccent = Color(NSColor.controlAccentColor)
}

public extension String {
    // Adding minor utility extensions as requested
    func trimmed() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
