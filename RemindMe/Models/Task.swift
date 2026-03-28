import Foundation

public struct ReminderTask: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public let createdAt: Date
    public var reminderFiresAt: Date
    public var state: TaskState
    public var reminderFired: Bool
    public var reminderFiredAt: Date?
    
    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        reminderFiresAt: Date,
        state: TaskState = .active,
        reminderFired: Bool = false,
        reminderFiredAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.reminderFiresAt = reminderFiresAt
        self.state = state
        self.reminderFired = reminderFired
        self.reminderFiredAt = reminderFiredAt
    }
}
