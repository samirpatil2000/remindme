import Foundation
import IOKit.pwr_mgt

@MainActor
public final class CaffeinateManager: ObservableObject {
    @Published public private(set) var isActive = false
    @Published public private(set) var expiresAt: Date?
    
    @Published public var keepDisplayAwake = true {
        didSet {
            if isActive {
                let remaining = expiresAt?.timeIntervalSinceNow
                start(duration: remaining)
            }
        }
    }
    
    @Published public var keepAwakeOnLidClose = false {
        didSet {
            if keepAwakeOnLidClose {
                if isLidSleepAuthorized {
                    setLidSleepDisabled(true)
                }
            } else {
                setLidSleepDisabled(false)
            }
        }
    }

    private var systemAssertion: IOPMAssertionID = 0
    private var displayAssertion: IOPMAssertionID = 0
    private var timer: Timer?

    public init() {}
    
    public var isLidSleepAuthorized: Bool {
        FileManager.default.fileExists(atPath: "/etc/sudoers.d/remindme-disablesleep")
    }
    
    public func authorizeLidSleep() -> Bool {
        let username = NSUserName()
        let sudoersContent = "\(username) ALL=(ALL) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"
        let script = """
        do shell script "echo '\(sudoersContent)' > /etc/sudoers.d/remindme-disablesleep && chmod 440 /etc/sudoers.d/remindme-disablesleep" with administrator privileges
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("Error setting up sudoers: \(error)")
                return false
            }
            return true
        }
        return false
    }
    
    private func setLidSleepDisabled(_ disabled: Bool) {
        guard isLidSleepAuthorized else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["/usr/bin/pmset", "-a", "disablesleep", disabled ? "1" : "0"]
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Error running pmset disablesleep: \(error)")
        }
    }

    public func start(duration: TimeInterval? = nil) {
        stop()

        let assertionName = "RemindMe Stay Awake Session" as CFString
        
        var newSystemAssertion: IOPMAssertionID = 0
        let systemResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            assertionName,
            &newSystemAssertion
        )
        
        if systemResult == kIOReturnSuccess {
            systemAssertion = newSystemAssertion
            isActive = true
        } else {
            print("Failed to create system sleep assertion: \(systemResult)")
        }
        
        if keepDisplayAwake {
            var newDisplayAssertion: IOPMAssertionID = 0
            let displayResult = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                assertionName,
                &newDisplayAssertion
            )
            
            if displayResult == kIOReturnSuccess {
                displayAssertion = newDisplayAssertion
            } else {
                print("Failed to create display sleep assertion: \(displayResult)")
            }
        }
        
        if keepAwakeOnLidClose && isLidSleepAuthorized {
            setLidSleepDisabled(true)
        }

        if let duration, duration > 0 {
            expiresAt = Date().addingTimeInterval(duration)
            timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.stop()
                }
            }
        } else {
            expiresAt = nil
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil

        if systemAssertion != 0 {
            IOPMAssertionRelease(systemAssertion)
            systemAssertion = 0
        }
        
        if displayAssertion != 0 {
            IOPMAssertionRelease(displayAssertion)
            displayAssertion = 0
        }
        
        if keepAwakeOnLidClose && isLidSleepAuthorized {
            setLidSleepDisabled(false)
        }

        isActive = false
        expiresAt = nil
    }
}
