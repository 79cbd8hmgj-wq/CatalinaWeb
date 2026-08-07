#if os(macOS)
import ApplicationServices
import XCTest
@testable import CatalinaWebApp

final class OrionAccessibilityClientTests: XCTestCase {
    func testCatalogContainsOnlyVerifiedProfileAndFocusSelectors() {
        let catalog = OrionAccessibilityCatalog()

        XCTAssertEqual(catalog.fileMenuTitle, "File")
        XCTAssertEqual(catalog.profilesMenuTitle, "Profiles")
        XCTAssertEqual(catalog.viewMenuTitle, "View")
        XCTAssertEqual(catalog.focusModeIdentifier, "FocusMode")
        XCTAssertEqual(catalog.enableFocusModeTitle, "Enable Focus Mode")
        XCTAssertEqual(catalog.disableFocusModeTitle, "Disable Focus Mode")
        XCTAssertEqual(catalog.dedicatedProfileName, "CatalinaWeb")
        XCTAssertFalse(catalog.supportsAutomaticProfileCreation)
    }

    func testStringValueReturnsNilForUnsupportedAttribute() {
        let client = SystemOrionAccessibilityClient()
        let element = AXUIElementCreateApplication(-1)

        XCTAssertNil(
            client.stringValue(
                of: element,
                attribute: "CatalinaWebUnsupportedAttribute" as CFString
            )
        )
    }

    func testPressReturnsFalseForInvalidApplicationElement() {
        let client = SystemOrionAccessibilityClient()
        let element = AXUIElementCreateApplication(-1)

        XCTAssertFalse(client.press(element))
    }

    func testWindowsAreEmptyForInvalidApplicationElement() {
        let client = SystemOrionAccessibilityClient()
        let element = AXUIElementCreateApplication(-1)

        XCTAssertEqual(client.windows(of: element).count, 0)
    }
}
#endif
