import AppKit
import ApplicationServices
import Foundation

protocol AccessibilityAuthorizing: AnyObject {
    var isTrusted: Bool { get }
    func requestTrustPrompt()
    func openAccessibilityPreferences()
}

final class SystemAccessibilityAuthorizer: AccessibilityAuthorizing {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestTrustPrompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilityPreferences() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
