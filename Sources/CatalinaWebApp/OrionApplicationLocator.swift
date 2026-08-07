import AppKit
import CatalinaWebCore
import Foundation

struct LocatedOrionApplication: Equatable {
    let url: URL
    let bundleIdentifier: String?
    let localizedName: String
}

protocol OrionApplicationLocating: AnyObject {
    func locateDefaultOrion() -> LocatedOrionApplication?
    func locateDedicatedProfile(matching identity: OrionProfileIdentity?) -> LocatedOrionApplication?
}

final class SystemOrionApplicationLocator: OrionApplicationLocating {
    private let fileManager: FileManager
    private let defaultOrionCandidates: [URL]
    private let dedicatedProfileCandidates: [URL]

    convenience init(fileManager: FileManager = .default) {
        let home = fileManager.homeDirectoryForCurrentUser
        let defaultCandidates = Self.defaultCandidateURLs(homeDirectory: home)
        let dedicatedCandidates = [
            home.appendingPathComponent("Applications", isDirectory: true)
                .appendingPathComponent("Orion", isDirectory: true)
                .appendingPathComponent("Orion Profiles", isDirectory: true)
                .appendingPathComponent("CatalinaWeb.app", isDirectory: true)
        ]
        self.init(
            fileManager: fileManager,
            defaultOrionCandidates: defaultCandidates,
            dedicatedProfileCandidates: dedicatedCandidates
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
        defaultOrionCandidates: [URL],
        dedicatedProfileCandidates: [URL]
    ) {
        self.fileManager = fileManager
        self.defaultOrionCandidates = defaultOrionCandidates
        self.dedicatedProfileCandidates = dedicatedProfileCandidates
    }

    func locateDefaultOrion() -> LocatedOrionApplication? {
        for candidate in defaultOrionCandidates {
            if let located = application(at: candidate) {
                return located
            }
        }
        return nil
    }

    func locateDedicatedProfile(
        matching identity: OrionProfileIdentity?
    ) -> LocatedOrionApplication? {
        if let identity = identity {
            guard let located = application(at: identity.applicationURL) else {
                return nil
            }
            guard located.url.standardizedFileURL == identity.applicationURL.standardizedFileURL else {
                return nil
            }
            if let expectedBundleIdentifier = identity.bundleIdentifier,
               located.bundleIdentifier != expectedBundleIdentifier {
                return nil
            }
            guard located.localizedName == identity.localizedName else {
                return nil
            }
            return located
        }

        for candidate in dedicatedProfileCandidates {
            guard let located = application(at: candidate) else {
                continue
            }
            if located.localizedName == "CatalinaWeb" {
                return located
            }
        }
        return nil
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

        return LocatedOrionApplication(
            url: url.standardizedFileURL,
            bundleIdentifier: bundle.bundleIdentifier,
            localizedName: displayName
        )
    }
}
