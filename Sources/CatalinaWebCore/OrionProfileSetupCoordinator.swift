import Foundation

public struct OrionApplicationIdentity: Equatable {
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

public protocol OrionAccessibilityTrustChecking: AnyObject {
    var isTrusted: Bool { get }
}

public protocol OrionApplicationIdentityLocating: AnyObject {
    func locateDefaultOrionIdentity() -> OrionApplicationIdentity?
}

public enum OrionProfileSetupFailure: Equatable {
    case orionApplicationNotFound
}

public enum OrionProfileSetupResult: Equatable {
    case needsAccessibilityPermission
    case needsManualProfileCreation(profileName: String)
    case profileVerified(OrionProfileIdentity)
    case failed(OrionProfileSetupFailure)
}

public final class OrionProfileSetupCoordinator {
    public static let dedicatedProfileName = "CatalinaWeb"

    private let accessibility: OrionAccessibilityTrustChecking
    private let applicationLocator: OrionApplicationIdentityLocating
    private let profileMetadata: OrionProfileMetadataReading
    private let stateStore: WorkspaceStateStoring

    public init(
        accessibility: OrionAccessibilityTrustChecking,
        applicationLocator: OrionApplicationIdentityLocating,
        profileMetadata: OrionProfileMetadataReading,
        stateStore: WorkspaceStateStoring
    ) {
        self.accessibility = accessibility
        self.applicationLocator = applicationLocator
        self.profileMetadata = profileMetadata
        self.stateStore = stateStore
    }

    public func startOrResume() -> OrionProfileSetupResult {
        var state = stateStore.load()

        guard accessibility.isTrusted else {
            return .needsAccessibilityPermission
        }

        if state.setupStage == .notStarted {
            state.setupStage = .accessibilityAuthorized
            stateStore.save(state)
        }

        guard let metadata = profileMetadata.load(),
              let profile = metadata.profile(named: Self.dedicatedProfileName) else {
            return .needsManualProfileCreation(profileName: Self.dedicatedProfileName)
        }

        guard let application = applicationLocator.locateDefaultOrionIdentity() else {
            return .failed(.orionApplicationNotFound)
        }

        let identity = OrionProfileIdentity(
            applicationURL: application.applicationURL,
            bundleIdentifier: application.bundleIdentifier,
            localizedName: application.localizedName,
            profileIdentifier: profile.identifier,
            profileName: profile.name
        )

        var needsSave = false
        if state.orionProfileIdentity != identity {
            state.orionProfileIdentity = identity
            needsSave = true
        }

        if shouldAdvanceToProfileVerified(from: state.setupStage) {
            state.setupStage = .profileVerified
            needsSave = true
        }

        if needsSave {
            stateStore.save(state)
        }

        return .profileVerified(identity)
    }

    private func shouldAdvanceToProfileVerified(from stage: OrionSetupStage) -> Bool {
        switch stage {
        case .notStarted, .accessibilityAuthorized, .profileCreated:
            return true
        case .profileVerified, .windowVerified, .focusModeVerified, .complete:
            return false
        }
    }
}
