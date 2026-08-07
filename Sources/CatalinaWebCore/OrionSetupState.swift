import Foundation

public enum OrionSetupStage: String, Codable, Equatable {
    case notStarted
    case accessibilityAuthorized
    case profileCreated
    case profileVerified
    case windowVerified
    case focusModeVerified
    case complete
}

public struct OrionProfileIdentity: Codable, Equatable {
    public let applicationURL: URL
    public let bundleIdentifier: String?
    public let localizedName: String

    public init(
        applicationURL: URL,
        bundleIdentifier: String?,
        localizedName: String
    ) {
        self.applicationURL = applicationURL
        self.bundleIdentifier = bundleIdentifier
        self.localizedName = localizedName
    }
}
