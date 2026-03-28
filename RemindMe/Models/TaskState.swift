import Foundation

public enum TaskState: String, Codable {
    case active
    case pastDue
    case done
    case stillRunning
}
