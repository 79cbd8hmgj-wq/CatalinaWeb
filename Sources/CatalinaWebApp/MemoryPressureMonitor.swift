import CatalinaWebCore
import Dispatch
import Foundation

protocol MemoryPressureReading: AnyObject {
    var currentLevel: MemoryPressureLevel { get }
    func start()
    func stop()
}

final class MemoryPressureMonitor: MemoryPressureReading {
    private let queue: DispatchQueue
    private let normalResetDelay: TimeInterval
    private let onLevelChange: (MemoryPressureLevel) -> Void
    private let lock = NSLock()
    private var source: DispatchSourceMemoryPressure?
    private var resetWorkItem: DispatchWorkItem?
    private var storedLevel: MemoryPressureLevel = .normal

    init(
        queue: DispatchQueue = DispatchQueue(label: "com.catalinaweb.memory-pressure"),
        normalResetDelay: TimeInterval = 30,
        onLevelChange: @escaping (MemoryPressureLevel) -> Void = { _ in }
    ) {
        self.queue = queue
        self.normalResetDelay = normalResetDelay
        self.onLevelChange = onLevelChange
    }

    var currentLevel: MemoryPressureLevel {
        lock.lock()
        defer { lock.unlock() }
        return storedLevel
    }

    func start() {
        lock.lock()
        let alreadyStarted = source != nil
        lock.unlock()
        if alreadyStarted {
            return
        }

        let newSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: queue
        )
        newSource.setEventHandler { [weak self] in
            self?.handleSourceEvent()
        }

        lock.lock()
        if source == nil {
            source = newSource
            lock.unlock()
            newSource.resume()
        } else {
            lock.unlock()
            newSource.cancel()
        }
    }

    func stop() {
        lock.lock()
        let oldSource = source
        source = nil
        let oldReset = resetWorkItem
        resetWorkItem = nil
        lock.unlock()

        oldReset?.cancel()
        oldSource?.cancel()
    }

    func recordForTesting(_ level: MemoryPressureLevel) {
        record(level, scheduleNormalReset: false)
    }

    private func handleSourceEvent() {
        lock.lock()
        let pendingEvent = source?.data
        lock.unlock()

        guard let pressureEvent = pendingEvent else {
            return
        }
        if pressureEvent.contains(.critical) {
            record(.critical, scheduleNormalReset: true)
        } else if pressureEvent.contains(.warning) {
            record(.warning, scheduleNormalReset: true)
        }
    }

    private func record(_ level: MemoryPressureLevel, scheduleNormalReset: Bool) {
        lock.lock()
        storedLevel = level
        let previousReset = resetWorkItem
        resetWorkItem = nil
        lock.unlock()

        previousReset?.cancel()
        onLevelChange(level)

        guard scheduleNormalReset else {
            return
        }

        let reset = DispatchWorkItem { [weak self] in
            self?.record(.normal, scheduleNormalReset: false)
        }
        lock.lock()
        resetWorkItem = reset
        lock.unlock()
        queue.asyncAfter(deadline: .now() + normalResetDelay, execute: reset)
    }
}
