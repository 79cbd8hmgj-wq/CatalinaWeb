import XCTest
@testable import CatalinaWebCore

final class OrionSetupStateTests: XCTestCase {
    func testSetupStagesHaveStableCodableRawValues() throws {
        let stages: [OrionSetupStage] = [
            .notStarted,
            .accessibilityAuthorized,
            .profileCreated,
            .profileVerified,
            .windowVerified,
            .focusModeVerified,
            .complete
        ]

        let data = try JSONEncoder().encode(stages)
        let decoded = try JSONDecoder().decode([OrionSetupStage].self, from: data)

        XCTAssertEqual(decoded, stages)
    }

    func testProfileIdentityRoundTripsExactly() throws {
        let identity = OrionProfileIdentity(
            applicationURL: URL(fileURLWithPath: "/Users/test/Applications/Orion/Orion Profiles/CatalinaWeb.app"),
            bundleIdentifier: "com.example.CatalinaWeb",
            localizedName: "CatalinaWeb"
        )

        let data = try JSONEncoder().encode(identity)
        let decoded = try JSONDecoder().decode(OrionProfileIdentity.self, from: data)

        XCTAssertEqual(decoded, identity)
    }
}
