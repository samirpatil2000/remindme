import Foundation

public enum ParseError: Error, Equatable {
    case invalidToken
    case noTitle
}

public struct ReminderParser {
    public static func parse(_ input: String, now: () -> Date = Date.init) -> Result<(title: String, firesAt: Date), ParseError> {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedInput.isEmpty {
            return .failure(.noTitle)
        }
        
        let pattern = "(?:^|\\s)(@[^\\s]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return .failure(.invalidToken) // Unlikely
        }
        
        let matches = regex.matches(in: trimmedInput, range: NSRange(trimmedInput.startIndex..., in: trimmedInput))
        
        var validTokenRange: NSRange?
        var validDuration: TimeInterval?
        
        for match in matches {
            let tokenNSRange = match.range(at: 1)
            guard let tokenRange = Range(tokenNSRange, in: trimmedInput) else { continue }
            
            let tokenStr = String(trimmedInput[tokenRange])
            
            if let token = TimeToken(fromString: tokenStr) {
                validTokenRange = match.range(at: 0) // The full match including the leading space if any
                validDuration = token.duration
                break
            }
        }
        
        // If there were @ words but none were valid time tokens
        if !matches.isEmpty && validDuration == nil {
            return .failure(.invalidToken)
        }
        
        let finalDuration = validDuration ?? 600 // Default 10 minutes
        let fireDate = now().addingTimeInterval(finalDuration)
        
        var title = trimmedInput
        if let validTokenRange = validTokenRange, let swiftRange = Range(validTokenRange, in: title) {
            title.removeSubrange(swiftRange)
        }
        
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            return .failure(.noTitle)
        }
        
        return .success((title: title, firesAt: fireDate))
    }
}
