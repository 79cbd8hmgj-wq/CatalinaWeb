import Foundation
import XCTest
@testable import CatalinaWebCore

final class OrionProfileSetupCoordinatorTests: XCTestCase {
    func testSetupStopsBeforeProfileWorkWhenAccessibilityIsMissing() {
        let stateStore = FakeWorkspaceStateStore(state: .initial)
        let metadata = FakeProfileMetadataReader(metadata: metadataWithCatalinaWeb())
        let locator = FakeOrionApplicationIdentityLocator(identity: orionHostIdentity())
        let coordinator = OrionProfileSetupCoordinator(
            accessibility: FakeAccessibilityTrustChecker(isTrusted: false),
            applicationLocator: locator,
            profileMetadata: metadata,
            stateStore: stateStore
        )

        let result = coordinator.startOrResume()

        XCTAssertEqual(result, .needsAccessibilityPermission)
        XCTAssertEqual(metadata.loadCount, 0)
        XCTAssertEqual(locator.lookupCount, 0)
        XCTAssertEqual(stateStore.savedStates, [])
    }

    func testMissingManualProfileStopsAfterAccessibilityVerification() {
        let stateStore = FakeWorkspaceStateStore(state: .initial)
        let metadata = FakeProfileMetadataReader(
            metadata: OrionProfileMetadata(
                defaultProfile: OrionProfileRecord(identifier: "Defaults", name: "Primary"),
                profiles: []
            )
        )
        let locator = FakeOrionApplicationIdentityLocator(identity: orionHostIdentity())
        let coordinator = OrionProfileSetupCoordinator(
            accessibility: FakeAccessibilityTrustChecker(isTrusted: true),
            applicationLocator: locator,
            profileMetadata: metadata,
            stateStore: stateStore
        )

        let result = coordinator.startOrResume()

        XCTAssertEqual(result, .needsManualProfileCreation(profileName: "CatalinaWeb"))
        XCTAssertEqual(locator.lookupCount, 0)
        XCTAssertEqual(stateStore.state.setupStage, .accessibilityAuthorized)
        XCTAssertNil(stateStore.state.orionProfileIdentity)
    }

    func testExistingManualProfileIsVerifiedAgainstSharedOrionHost() {
        let stateStore = FakeWorkspaceStateStore(state: .initial)
        let coordinator = OrionProfileSetupCoordinator(
            accessibility: FakeAccessibilityTrustChecker(isTrusted: true),
            applicationLocator: FakeOrionApplicationIdentityLocator(identity: orionHostIdentity()),
            profileMetadata: FakeProfileMetadataReader(metadata: metadataWithCatalinaWeb()),
            stateStore: stateStore
        )

        let result = coordinator.startOrResume()

        let expectedIdentity = OrionProfileIdentity(
            applicationURL: URL(fileURLWithPath: "/Applications/Utilities/Orion.app"),
            bundleIdentifier: "com.kagi.kagimacOS",
            localizedName: "Orion",
            profileIdentifier: "PROFILE-ID",
            profileName: "CatalinaWeb"
        )
        XCTAssertEqual(result, .profileVerified(expectedIdentity))
        XCTAssertEqual(stateStore.state.setupStage, .profileVerified)
        XCTAssertEqual(stateStore.state.orionProfileIdentity, expectedIdentity)
    }

    func testMissingOrionHostDoesNotMarkProfileVerified() {
        let stateStore = FakeWorkspaceStateStore(state: .initial)
        let coordinator = OrionProfileSetupCoordinator(
            accessibility: FakeAccessibilityTrustChecker(isTrusted: true),
            applicationLocator: FakeOrionApplicationIdentityLocator(identity: nil),
            profileMetadata: FakeProfileMetadataReader(metadata: metadataWithCatalinaWeb()),
            stateStore: stateStore
        )

        let result = coordinator.startOrResume()

        XCTAssertEqual(result, .failed(.orionApplicationNotFound))
        XCTAssertEqual(stateStore.state.setupStage, .accessibilityAuthorized)
        XCTAssertNil(stateStore.state.orionProfileIdentity)
    }

    func testReverificationDoesNotRegressLaterSetupStage() {
        var state = PersistedWorkspaceState.initial
        state.setupStage = .complete
        let stateStore = FakeWorkspaceStateStore(state: state)
        let coordinator = OrionProfileSetupCoordinator(
            accessibility: FakeAccessibilityTrustChecker(isTrusted: true),
            applicationLocator: FakeOrionApplicationIdentityLocator(identity: orionHostIdentity()),
            profileMetadata: FakeProfileMetadataReader(metadata: metadataWithCatalinaWeb()),
            stateStore: stateStore
        )

        let result = coordinator.startOrResume()

        guard case .profileVerified = result else {
            return XCTFail("Expected verified profile")
        }
        XCTAssertEqual(stateStore.state.setupStage, .complete)
        XCTAssertEqual(stateStore.state.orionProfileIdentity?.profileIdentifier, "PROFILE-ID")
    }

    private func metadataWithCatalinaWeb() -> OrionProfileMetadata {
        OrionProfileMetadata(
            defaultProfile: OrionProfileRecord(identifier: "Defaults", name: "Primary"),
            profiles: [OrionProfileRecord(identifier: "PROFILE-ID", name: "CatalinaWeb")]
        )
    }

    private func orionHostIdentity() -> OrionApplicationIdentity {
        OrionApplicationIdentity(
            applicationURL: URL(fileURLWithPath: "/Applications/Utilities/Orion.app"),
            bundleIdentifier: "com.kagi.kagimacOS",
            localizedName: "Orion"
        )
    }
}

private final class FakeAccessibilityTrustChecker: OrionAccessibilityTrustChecking {
    let isTrusted: Bool

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }
}

private final class FakeOrionApplicationIdentityLocator: OrionApplicationIdentityLocating {
    let identity: OrionApplicationIdentity?
    private(set) var lookupCount = 0

    init(identity: OrionApplicationIdentity?) {
        self.identity = identity
    }

    func locateDefaultOrionIdentity() -> OrionApplicationIdentity? {
        lookupCount += 1
        return identity
    }
}

private final class FakeProfileMetadataReader: OrionProfileMetadataReading {
    let metadata: OrionProfileMetadata?
    private(set) var loadCount = 0

    init(metadata: OrionProfileMetadata?) {
        self.metadata = metadata
    }

    func load() -> OrionProfileMetadata? {
        loadCount += 1
        return metadata
    }
}

private final class FakeWorkspaceStateStore: WorkspaceStateStoring {
    var state: PersistedWorkspaceState
    private(set) var savedStates: [PersistedWorkspaceState] = []

    init(state: PersistedWorkspaceState) {
        self.state = state
    }

    func load() -> PersistedWorkspaceState {
        state
    }

    func save(_ state: PersistedWorkspaceState) {
        self.state = state
        savedStates.append(state)
    }
}
