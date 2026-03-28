import Foundation

public struct TimeToken {
    public let duration: TimeInterval
    
    public init?(fromString token: String) {
        let strictPattern = "^@([0-9]+[hms])+$"
        guard token.range(of: strictPattern, options: .regularExpression) != nil else {
            return nil
        }
        
        let extractPattern = "([0-9]+)([hms])"
        guard let regex = try? NSRegularExpression(pattern: extractPattern) else { return nil }
        
        let matches = regex.matches(in: token, range: NSRange(token.startIndex..., in: token))
        
        var totalSeconds: TimeInterval = 0
        for match in matches {
            guard let numberRange = Range(match.range(at: 1), in: token),
                  let unitRange = Range(match.range(at: 2), in: token),
                  let number = Int(token[numberRange]) else {
                continue
            }
            
            let unit = token[unitRange]
            switch unit {
            case "h": totalSeconds += TimeInterval(number * 3600)
            case "m": totalSeconds += TimeInterval(number * 60)
            case "s": totalSeconds += TimeInterval(number)
            default: break
            }
        }
        
        guard totalSeconds > 0 else { return nil }
        self.duration = totalSeconds
    }
}
