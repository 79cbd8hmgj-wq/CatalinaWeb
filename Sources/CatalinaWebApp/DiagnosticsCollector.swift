import CatalinaProcessMetrics
import CatalinaWebCore
import Darwin
import Foundation

struct ProcessFamilyMeasurement: Equatable {
    let rootResidentBytes: UInt64?
    let attributableChildProcessCount: Int?
    let attributableFamilyResidentBytes: UInt64?

    static let unavailable = ProcessFamilyMeasurement(
        rootResidentBytes: nil,
        attributableChildProcessCount: nil,
        attributableFamilyResidentBytes: nil
    )
}

protocol ProcessFamilyMetricsReading {
    func readCurrentProcessFamily() -> ProcessFamilyMeasurement
}

final class LibprocProcessFamilyMetricsReader: ProcessFamilyMetricsReading {
    func readCurrentProcessFamily() -> ProcessFamilyMeasurement {
        var nativeMetrics = CWProcessFamilyMetrics()
        let result = cw_read_process_family_metrics(Int32(getpid()), &nativeMetrics)

        let rootBytes: UInt64? = nativeMetrics.root_resident_bytes > 0
            ? nativeMetrics.root_resident_bytes
            : nil

        guard result == 0, nativeMetrics.status == 0 else {
            return ProcessFamilyMeasurement(
                rootResidentBytes: rootBytes,
                attributableChildProcessCount: nil,
                attributableFamilyResidentBytes: nil
            )
        }

        let (familyBytes, overflow) = nativeMetrics.root_resident_bytes.addingReportingOverflow(
            nativeMetrics.descendant_resident_bytes
        )
        let count = Int(nativeMetrics.descendant_count)

        return ProcessFamilyMeasurement(
            rootResidentBytes: rootBytes,
            attributableChildProcessCount: count,
            attributableFamilyResidentBytes: overflow ? nil : familyBytes
        )
    }
}

final class DiagnosticsCollector: BrowserEventRecording {
    typealias ContextProvider = () -> (workspace: Workspace, liveWebViewCount: Int)

    private let contextProvider: ContextProvider
    private let processMetricsReader: ProcessFamilyMetricsReading
    private let memoryPressureReader: MemoryPressureReading
    private let lock = NSLock()
    private var events: [BrowserEvent] = []
    private let maximumEventCount = 200

    init(
        contextProvider: @escaping ContextProvider,
        processMetricsReader: ProcessFamilyMetricsReading = LibprocProcessFamilyMetricsReader(),
        memoryPressureReader: MemoryPressureReading = MemoryPressureMonitor()
    ) {
        self.contextProvider = contextProvider
        self.processMetricsReader = processMetricsReader
        self.memoryPressureReader = memoryPressureReader
        memoryPressureReader.start()
    }

    deinit {
        memoryPressureReader.stop()
    }

    func record(_ event: BrowserEvent) {
        lock.lock()
        events.append(event)
        if events.count > maximumEventCount {
            events.removeFirst(events.count - maximumEventCount)
        }
        lock.unlock()
    }

    func recentEvents() -> [BrowserEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    func currentSnapshot() -> DiagnosticsSnapshot {
        let context = contextProvider()
        let processMeasurement = processMetricsReader.readCurrentProcessFamily()
        return DiagnosticsSnapshot(
            timestamp: Date(),
            activeWorkspace: context.workspace,
            liveWebViewCount: context.liveWebViewCount,
            appResidentBytes: processMeasurement.rootResidentBytes,
            attributableChildProcessCount: processMeasurement.attributableChildProcessCount,
            attributableFamilyResidentBytes: processMeasurement.attributableFamilyResidentBytes,
            memoryPressure: memoryPressureReader.currentLevel
        )
    }
}
