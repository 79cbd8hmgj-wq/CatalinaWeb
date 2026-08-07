import CatalinaWebCore
import Foundation

typealias LocatedOrionApplication = OrionApplicationIdentity

protocol OrionApplicationLocating: OrionApplicationIdentityLocating {
    func locateDefaultOrion() -> LocatedOrionApplication?
}

final class SystemOrionApplicationLocator: OrionApplicationLocating {
    private let fileManager: FileManager
    private let defaultOrionCandidates: [URL]

    convenience init(fileManager: FileManager = .default) {
        let home = fileManager.homeDirectoryForCurrentUser
        self.init(
            fileManager: fileManager,
            defaultOrionCandidates: Self.defaultCandidateURLs(homeDirectory: home)
        )
    }

    static func defaultCandidateURLs(homeDirectory: URL) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications/Orion.app", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Utilities/Orion.app", isDirectory: true),
            homeDirectory.appendingPathComponent("Applications", isDirectory: true)
                .appendingPathComponent("Orion.app", isDirectory: true)
        ]
    }

    init(
        fileManager: FileManager = .default,
        defaultOrionCandidates: [URL]
    ) {
        self.fileManager = fileManager
        self.defaultOrionCandidates = defaultOrionCandidates
    }

    func locateDefaultOrion() -> LocatedOrionApplication? {
        for candidate in defaultOrionCandidates {
            if let located = application(at: candidate) {
                return located
            }
        }
        return nil
    }

    func locateDefaultOrionIdentity() -> OrionApplicationIdentity? {
        locateDefaultOrion()
    }

    private func application(at url: URL) -> LocatedOrionApplication? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              let bundle = Bundle(url: url) else {
            return nil
        }

        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent

        return OrionApplicationIdentity(
            applicationURL: url.standardizedFileURL,
            bundleIdentifier: bundle.bundleIdentifier,
            localizedName: displayName
        )
    }
}
