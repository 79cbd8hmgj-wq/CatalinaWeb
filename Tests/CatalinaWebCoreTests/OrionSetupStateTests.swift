import Foundation
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

    func testProfileIdentityRoundTripsSharedOrionHostAndProfileIdentity() throws {
        let identity = OrionProfileIdentity(
            applicationURL: URL(fileURLWithPath: "/Applications/Utilities/Orion.app"),
            bundleIdentifier: "com.kagi.kagimacOS",
            localizedName: "Orion",
            profileIdentifier: "PROFILE-ID",
            profileName: "CatalinaWeb"
        )

        let data = try JSONEncoder().encode(identity)
        let decoded = try JSONDecoder().decode(OrionProfileIdentity.self, from: data)

        XCTAssertEqual(decoded, identity)
    }

    func testProfileIdentityDecodesLegacyV2PayloadWithoutProfileFields() throws {
        let legacyJSON = """
        {
          "applicationURL": "file:///Users/test/Applications/Orion/Orion%20Profiles/CatalinaWeb.app/",
          "bundleIdentifier": "com.example.CatalinaWeb",
          "localizedName": "CatalinaWeb"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(OrionProfileIdentity.self, from: legacyJSON)

        XCTAssertNil(decoded.profileIdentifier)
        XCTAssertNil(decoded.profileName)
    }
}
