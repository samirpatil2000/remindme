import Foundation

@MainActor
public final class CaffeinateManager: ObservableObject {
    @Published public private(set) var isActive = false
    @Published public private(set) var expiresAt: Date?

    private var process: Process?
    private var timer: Timer?

    public init() {}

    public func start(duration: TimeInterval? = nil) {
        stop()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = ["-d", "-i"]

        do {
            try process.run()
            self.process = process
            isActive = true
            expiresAt = duration.map { Date().addingTimeInterval($0) }

            if let duration {
                timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.stop()
                    }
                }
            }
        } catch {
            self.process = nil
            isActive = false
            expiresAt = nil
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil

        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        isActive = false
        expiresAt = nil
    }
}
