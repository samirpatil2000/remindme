import Foundation
import Combine

public class RecentTimesStore: ObservableObject {
    @Published public private(set) var recentTimes: [TimeInterval] = []
    
    private let maxCount = 5
    private let defaultsKey = "RemindMe.RecentTimes"
    private let defaults = UserDefaults.standard
    
    // Default starting times for a new user
    private let defaultTimes: [TimeInterval] = [300, 600, 900] // 5m, 10m, 15m
    
    public init() {
        load()
    }
    
    public func add(_ time: TimeInterval) {
        // Remove if exists to move to front
        recentTimes.removeAll { $0 == time }
        
        // Add to front
        recentTimes.insert(time, at: 0)
        
        // Trim to max count
        if recentTimes.count > maxCount {
            recentTimes = Array(recentTimes.prefix(maxCount))
        }
        
        save()
    }
    
    private func load() {
        if let array = defaults.array(forKey: defaultsKey) as? [Double], !array.isEmpty {
            recentTimes = array
        } else {
            recentTimes = defaultTimes
        }
    }
    
    private func save() {
        defaults.set(recentTimes, forKey: defaultsKey)
    }
}
