#if os(macOS)
import Foundation
import XCTest
@testable import CatalinaWebApp
@testable import CatalinaWebCore

final class OrionApplicationLocatorTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CatalinaWeb-OrionLocatorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory = temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func testDefaultOrionUsesCandidateOrder() throws {
        let systemCandidate = try makeApplication(
            name: "System Orion",
            bundleIdentifier: "com.kagi.kagimacOS",
            parent: temporaryDirectory
        )
        let userCandidate = try makeApplication(
            name: "User Orion",
            bundleIdentifier: "com.kagi.kagimacOS.user",
            parent: temporaryDirectory
        )
        let locator = SystemOrionApplicationLocator(
            defaultOrionCandidates: [systemCandidate, userCandidate],
            dedicatedProfileCandidates: []
        )

        let located = locator.locateDefaultOrion()

        XCTAssertEqual(located?.url.standardizedFileURL, systemCandidate.standardizedFileURL)
        XCTAssertEqual(located?.bundleIdentifier, "com.kagi.kagimacOS")
        XCTAssertEqual(located?.localizedName, "System Orion")
    }

    func testDedicatedLookupRefusesPersistedIdentityWhenBundleIdentifierDoesNotMatch() throws {
        let dedicated = try makeApplication(
            name: "CatalinaWeb",
            bundleIdentifier: "com.kagi.real-profile",
            parent: temporaryDirectory
        )
        let locator = SystemOrionApplicationLocator(
            defaultOrionCandidates: [],
            dedicatedProfileCandidates: [dedicated]
        )
        let identity = OrionProfileIdentity(
            applicationURL: dedicated,
            bundleIdentifier: "com.kagi.wrong-profile",
            localizedName: "CatalinaWeb"
        )

        XCTAssertNil(locator.locateDedicatedProfile(matching: identity))
    }

    func testDedicatedLookupAcceptsMatchingPersistedIdentity() throws {
        let dedicated = try makeApplication(
            name: "CatalinaWeb",
            bundleIdentifier: "com.kagi.catalinaweb-profile",
            parent: temporaryDirectory
        )
        let locator = SystemOrionApplicationLocator(
            defaultOrionCandidates: [],
            dedicatedProfileCandidates: [dedicated]
        )
        let identity = OrionProfileIdentity(
            applicationURL: dedicated,
            bundleIdentifier: "com.kagi.catalinaweb-profile",
            localizedName: "CatalinaWeb"
        )

        let located = locator.locateDedicatedProfile(matching: identity)

        XCTAssertEqual(located?.url.standardizedFileURL, dedicated.standardizedFileURL)
        XCTAssertEqual(located?.localizedName, "CatalinaWeb")
    }

    func testDedicatedLookupWithoutIdentityUsesOnlyCatalinaWebProfileCandidate() throws {
        let normal = try makeApplication(
            name: "Orion",
            bundleIdentifier: "com.kagi.normal",
            parent: temporaryDirectory
        )
        let dedicated = try makeApplication(
            name: "CatalinaWeb",
            bundleIdentifier: "com.kagi.catalinaweb-profile",
            parent: temporaryDirectory
        )
        let locator = SystemOrionApplicationLocator(
            defaultOrionCandidates: [normal],
            dedicatedProfileCandidates: [dedicated]
        )

        let located = locator.locateDedicatedProfile(matching: nil)

        XCTAssertEqual(located?.url.standardizedFileURL, dedicated.standardizedFileURL)
        XCTAssertEqual(located?.localizedName, "CatalinaWeb")
    }

    private func makeApplication(
        name: String,
        bundleIdentifier: String,
        parent: URL
    ) throws -> URL {
        let appURL = parent.appendingPathComponent("\(name).app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(
            at: contentsURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let info: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": name,
            "CFBundleDisplayName": name,
            "CFBundlePackageType": "APPL"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
        return appURL
    }
}
#endif
