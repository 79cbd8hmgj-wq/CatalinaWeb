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

    func testDefaultCandidatePathsIncludeCatalinaUtilitiesInstallation() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
        let candidates = SystemOrionApplicationLocator.defaultCandidateURLs(homeDirectory: home)
            .map { $0.standardizedFileURL.path }

        XCTAssertEqual(candidates, [
            "/Applications/Orion.app",
            "/Applications/Utilities/Orion.app",
            "/Users/example/Applications/Orion.app"
        ])
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
            defaultOrionCandidates: [systemCandidate, userCandidate]
        )

        let located = locator.locateDefaultOrion()

        XCTAssertEqual(located?.applicationURL.standardizedFileURL, systemCandidate.standardizedFileURL)
        XCTAssertEqual(located?.bundleIdentifier, "com.kagi.kagimacOS")
        XCTAssertEqual(located?.localizedName, "System Orion")
    }

    func testCoreIdentityAdapterUsesSameSharedOrionHost() throws {
        let orion = try makeApplication(
            name: "Orion",
            bundleIdentifier: "com.kagi.kagimacOS",
            parent: temporaryDirectory
        )
        let locator = SystemOrionApplicationLocator(defaultOrionCandidates: [orion])

        let identity = locator.locateDefaultOrionIdentity()

        XCTAssertEqual(
            identity,
            OrionApplicationIdentity(
                applicationURL: orion.standardizedFileURL,
                bundleIdentifier: "com.kagi.kagimacOS",
                localizedName: "Orion"
            )
        )
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
