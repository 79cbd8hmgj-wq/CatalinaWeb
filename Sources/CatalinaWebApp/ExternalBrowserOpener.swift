import AppKit
import Foundation

public protocol ExternalBrowserOpening: AnyObject {
    func openExternally(_ url: URL)
}

public final class OrionExternalBrowserOpener: ExternalBrowserOpening {
    private let workspace: NSWorkspace
    private let fileManager: FileManager

    public init(
        workspace: NSWorkspace = .shared,
        fileManager: FileManager = .default
    ) {
        self.workspace = workspace
        self.fileManager = fileManager
    }

    public func openExternally(_ url: URL) {
        guard let orionURL = resolveOrionApplicationURL() else {
            _ = workspace.open(url)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.open(
            [url],
            withApplicationAt: orionURL,
            configuration: configuration,
            completionHandler: nil
        )
    }

    private func resolveOrionApplicationURL() -> URL? {
        let candidates = [
            URL(fileURLWithPath: "/Applications/Orion.app", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true)
                .appendingPathComponent("Orion.app", isDirectory: true)
        ]

        return candidates.first { candidate in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory)
                && isDirectory.boolValue
        }
    }
}
