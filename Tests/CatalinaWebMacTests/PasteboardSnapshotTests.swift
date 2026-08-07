#if os(macOS)
import AppKit
import XCTest
@testable import CatalinaWebApp

final class PasteboardSnapshotTests: XCTestCase {
    func testSnapshotRestoresEveryItemTypeAndItemOrder() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("CatalinaWeb-PasteboardSnapshotTests-\(UUID().uuidString)"))
        let arbitraryType = NSPasteboard.PasteboardType("com.catalinaweb.test.binary")

        let first = NSPasteboardItem()
        first.setString("first", forType: .string)
        first.setData(Data([0x01, 0x02, 0x03]), forType: arbitraryType)

        let second = NSPasteboardItem()
        second.setString("second", forType: .string)

        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([first, second]))

        let snapshot = PasteboardSnapshot.capture(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("replacement", forType: .string)
        snapshot.restore(to: pasteboard)

        let restored = pasteboard.pasteboardItems ?? []
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored[0].string(forType: .string), "first")
        XCTAssertEqual(restored[0].data(forType: arbitraryType), Data([0x01, 0x02, 0x03]))
        XCTAssertEqual(restored[1].string(forType: .string), "second")
    }

    func testEmptySnapshotClearsPasteboard() {
        let source = NSPasteboard(name: NSPasteboard.Name("CatalinaWeb-PasteboardSnapshotTests-Source-\(UUID().uuidString)"))
        let destination = NSPasteboard(name: NSPasteboard.Name("CatalinaWeb-PasteboardSnapshotTests-Destination-\(UUID().uuidString)"))

        source.clearContents()
        let snapshot = PasteboardSnapshot.capture(source)

        destination.clearContents()
        destination.setString("temporary", forType: .string)
        snapshot.restore(to: destination)

        XCTAssertTrue((destination.pasteboardItems ?? []).isEmpty)
    }
}
#endif
