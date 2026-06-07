import Foundation
import IOKit.ps

public struct BatteryState: Equatable {
    public let percentage: Int
    public let isCharging: Bool
    public let isConnectedToPower: Bool
}

@MainActor
public final class BatteryManager: ObservableObject {
    @Published public private(set) var currentState: BatteryState?
    public var onBatteryStateChanged: ((BatteryState) -> Void)?
    
    private var runLoopSource: CFRunLoopSource?
    
    public init() {
        self.currentState = queryCurrentState()
    }
    
    public func startMonitoring() {
        guard runLoopSource == nil else { return }
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        let callback: @convention(c) (UnsafeMutableRawPointer?) -> Void = { context in
            guard let context = context else { return }
            let manager = Unmanaged<BatteryManager>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                manager.powerSourcesChanged()
            }
        }
        
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
        }
        
        // Initial query to populate state
        powerSourcesChanged()
    }
    
    public func stopMonitoring() {
        guard let source = runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
        runLoopSource = nil
    }
    
    private func powerSourcesChanged() {
        if let newState = queryCurrentState() {
            if newState != currentState {
                currentState = newState
                onBatteryStateChanged?(newState)
            }
        }
    }
    
    private func queryCurrentState() -> BatteryState? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        
        for source in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                guard info["Is Present"] as? Bool == true else { continue }
                
                if let current = info["Current Capacity"] as? Int,
                   let max = info["Max Capacity"] as? Int, max > 0 {
                    let percentage = Int(round(Double(current) / Double(max) * 100.0))
                    let isCharging = info["Is Charging"] as? Bool ?? false
                    let powerSourceState = info["Power Source State"] as? String
                    let isConnectedToPower = (powerSourceState == "AC Power")
                    
                    return BatteryState(
                        percentage: percentage,
                        isCharging: isCharging,
                        isConnectedToPower: isConnectedToPower
                    )
                }
            }
        }
        return nil
    }
}
