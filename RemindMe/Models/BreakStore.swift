import Foundation

public struct BreakStore {
    private let countKey = "RemindMe.BreaksTodayCount"
    private let dateKey = "RemindMe.BreaksTodayDate"
    
    public init() {}
    
    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    public var breaksToday: Int {
        let storedDate = UserDefaults.standard.string(forKey: dateKey) ?? ""
        if storedDate == todayString {
            return UserDefaults.standard.integer(forKey: countKey)
        } else {
            return 0
        }
    }
    
    public mutating func increment() {
        let currentCount = breaksToday
        UserDefaults.standard.set(currentCount + 1, forKey: countKey)
        UserDefaults.standard.set(todayString, forKey: dateKey)
    }
}
