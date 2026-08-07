import Foundation

public struct OrionProfileRecord: Equatable {
    public let identifier: String
    public let name: String

    public init(identifier: String, name: String) {
        self.identifier = identifier
        self.name = name
    }
}

public struct OrionProfileMetadata: Equatable {
    public let defaultProfile: OrionProfileRecord?
    public let profiles: [OrionProfileRecord]

    public init(
        defaultProfile: OrionProfileRecord?,
        profiles: [OrionProfileRecord]
    ) {
        self.defaultProfile = defaultProfile
        self.profiles = profiles
    }

    public func profile(named name: String) -> OrionProfileRecord? {
        profiles.first { $0.name == name }
    }
}

public enum OrionProfileMetadataParser {
    public static func parse(_ data: Data) -> OrionProfileMetadata? {
        guard let root = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            return nil
        }

        let defaultProfile: OrionProfileRecord?
        if let rawDefault = root["defaults"] {
            guard let dictionary = rawDefault as? [String: Any],
                  let parsed = record(from: dictionary) else {
                return nil
            }
            defaultProfile = parsed
        } else {
            defaultProfile = nil
        }

        let profiles: [OrionProfileRecord]
        if let rawProfiles = root["profiles"] {
            guard let dictionaries = rawProfiles as? [[String: Any]] else {
                return nil
            }
            var parsedProfiles: [OrionProfileRecord] = []
            parsedProfiles.reserveCapacity(dictionaries.count)
            for dictionary in dictionaries {
                guard let profile = record(from: dictionary) else {
                    return nil
                }
                parsedProfiles.append(profile)
            }
            profiles = parsedProfiles
        } else {
            profiles = []
        }

        return OrionProfileMetadata(
            defaultProfile: defaultProfile,
            profiles: profiles
        )
    }

    private static func record(from dictionary: [String: Any]) -> OrionProfileRecord? {
        guard let identifier = dictionary["identifier"] as? String,
              !identifier.isEmpty,
              let name = dictionary["name"] as? String,
              !name.isEmpty else {
            return nil
        }
        return OrionProfileRecord(identifier: identifier, name: name)
    }
}

public protocol OrionProfileMetadataReading: AnyObject {
    func load() -> OrionProfileMetadata?
}

public final class FileOrionProfileMetadataReader: OrionProfileMetadataReading {
    public let fileURL: URL

    public convenience init(fileManager: FileManager = .default) {
        let home = fileManager.homeDirectoryForCurrentUser
        let fileURL = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Orion", isDirectory: true)
            .appendingPathComponent("profiles", isDirectory: false)
        self.init(fileURL: fileURL)
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> OrionProfileMetadata? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return OrionProfileMetadataParser.parse(data)
    }
}
