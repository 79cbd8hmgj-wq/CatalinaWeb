import Foundation

public enum MemoryPressureLevel: String, Codable, Equatable {
    case normal
    case warning
    case critical

    public var displayName: String {
        switch self {
        case .normal:
            return "Normal"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        }
    }
}

public struct DiagnosticsSnapshot: Equatable {
    public let timestamp: Date
    public let activeWorkspace: Workspace
    public let liveWebViewCount: Int
    public let appResidentBytes: UInt64?
    public let attributableChildProcessCount: Int?
    public let attributableFamilyResidentBytes: UInt64?
    public let memoryPressure: MemoryPressureLevel

    public init(
        timestamp: Date,
        activeWorkspace: Workspace,
        liveWebViewCount: Int,
        appResidentBytes: UInt64?,
        attributableChildProcessCount: Int?,
        attributableFamilyResidentBytes: UInt64?,
        memoryPressure: MemoryPressureLevel
    ) {
        self.timestamp = timestamp
        self.activeWorkspace = activeWorkspace
        self.liveWebViewCount = liveWebViewCount
        self.appResidentBytes = appResidentBytes
        self.attributableChildProcessCount = attributableChildProcessCount
        self.attributableFamilyResidentBytes = attributableFamilyResidentBytes
        self.memoryPressure = memoryPressure
    }
}

public enum DiagnosticsFormatter {
    public static func bytes(_ value: UInt64?) -> String {
        guard let value = value else {
            return "Unavailable"
        }
        let bytes = Double(value)
        let gibibyte = 1024.0 * 1024.0 * 1024.0
        let mebibyte = 1024.0 * 1024.0
        let kibibyte = 1024.0

        if bytes >= gibibyte {
            return String(format: "%.2f GB", bytes / gibibyte)
        }
        if bytes >= mebibyte {
            return String(format: "%.2f MB", bytes / mebibyte)
        }
        if bytes >= kibibyte {
            return String(format: "%.2f KB", bytes / kibibyte)
        }
        return "\(value) B"
    }

    public static func processCount(_ value: Int?) -> String {
        guard let value = value else {
            return "Unavailable"
        }
        return String(value)
    }
}
