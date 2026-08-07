import Foundation
import XCTest
@testable import CatalinaWebCore

final class OrionProfileMetadataTests: XCTestCase {
    func testParserReadsDefaultAndSecondaryProfiles() throws {
        let data = try makeProfilesPlist()

        let metadata = OrionProfileMetadataParser.parse(data)

        XCTAssertEqual(
            metadata?.defaultProfile,
            OrionProfileRecord(identifier: "Defaults", name: "Primary")
        )
        XCTAssertEqual(
            metadata?.profiles,
            [OrionProfileRecord(identifier: "PROFILE-ID", name: "CatalinaWeb")]
        )
        XCTAssertEqual(
            metadata?.profile(named: "CatalinaWeb"),
            OrionProfileRecord(identifier: "PROFILE-ID", name: "CatalinaWeb")
        )
    }

    func testProfileLookupRequiresExactName() throws {
        let metadata = OrionProfileMetadataParser.parse(try makeProfilesPlist())

        XCTAssertNil(metadata?.profile(named: "catalinaweb"))
        XCTAssertNil(metadata?.profile(named: "CatalinaWeb "))
    }

    func testParserRejectsMalformedProfileEntries() throws {
        let object: [String: Any] = [
            "defaults": ["identifier": "Defaults", "name": "Primary"],
            "profiles": [["identifier": "PROFILE-ID"]]
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: object,
            format: .xml,
            options: 0
        )

        XCTAssertNil(OrionProfileMetadataParser.parse(data))
    }

    func testFileReaderReturnsNilWhenProfilesFileDoesNotExist() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-orion-profiles-\(UUID().uuidString)")
        let reader = FileOrionProfileMetadataReader(fileURL: url)

        XCTAssertNil(reader.load())
    }

    func testFileReaderLoadsExistingProfilesFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CatalinaWeb-OrionProfileMetadata-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("profiles")
        try makeProfilesPlist().write(to: url)
        let reader = FileOrionProfileMetadataReader(fileURL: url)

        XCTAssertEqual(
            reader.load()?.profile(named: "CatalinaWeb"),
            OrionProfileRecord(identifier: "PROFILE-ID", name: "CatalinaWeb")
        )
    }

    private func makeProfilesPlist() throws -> Data {
        let object: [String: Any] = [
            "defaults": [
                "color": 7,
                "identifier": "Defaults",
                "name": "Primary"
            ],
            "profiles": [[
                "color": 4,
                "identifier": "PROFILE-ID",
                "name": "CatalinaWeb"
            ]]
        ]
        return try PropertyListSerialization.data(
            fromPropertyList: object,
            format: .xml,
            options: 0
        )
    }
}
