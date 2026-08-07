import AppKit
import ApplicationServices
import Foundation

private let maximumTreeDepth = 8
private let maximumChildrenPerElement = 80

private func copiedValue(
    _ element: AXUIElement,
    attribute: CFString
) -> CFTypeRef? {
    var rawValue: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, attribute, &rawValue)
    guard error == .success else {
        return nil
    }
    return rawValue
}

private func stringValue(
    _ element: AXUIElement,
    attribute: CFString
) -> String? {
    copiedValue(element, attribute: attribute) as? String
}

private func boolValue(
    _ element: AXUIElement,
    attribute: CFString
) -> Bool? {
    copiedValue(element, attribute: attribute) as? Bool
}

private func elementsValue(
    _ element: AXUIElement,
    attribute: CFString
) -> [AXUIElement] {
    copiedValue(element, attribute: attribute) as? [AXUIElement] ?? []
}

private func urlOnlyValue(_ element: AXUIElement) -> String? {
    guard let raw = stringValue(element, attribute: kAXValueAttribute as CFString),
          let url = URL(string: raw),
          let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https" else {
        return nil
    }
    return raw
}

private func shouldPrintSemanticText(for role: String?) -> Bool {
    guard let role = role else {
        return false
    }

    let allowedRoles: Set<String> = [
        kAXMenuBarRole as String,
        kAXMenuBarItemRole as String,
        kAXMenuRole as String,
        kAXMenuItemRole as String,
        kAXButtonRole as String,
        kAXTextFieldRole as String,
        kAXComboBoxRole as String,
        kAXToolbarRole as String,
        kAXPopUpButtonRole as String,
        kAXCheckBoxRole as String,
        kAXRadioButtonRole as String
    ]
    return allowedRoles.contains(role)
}

private func sanitized(_ string: String) -> String {
    string
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
        .prefix(180)
        .description
}

private func elementSummary(_ element: AXUIElement) -> String {
    let role = stringValue(element, attribute: kAXRoleAttribute as CFString)
    let subrole = stringValue(element, attribute: kAXSubroleAttribute as CFString)
    let identifier = stringValue(element, attribute: kAXIdentifierAttribute as CFString)
    let enabled = boolValue(element, attribute: kAXEnabledAttribute as CFString)

    var fields: [String] = []
    fields.append("role=\(role ?? "<none>")")

    if let subrole = subrole, !subrole.isEmpty {
        fields.append("subrole=\(sanitized(subrole))")
    }
    if let identifier = identifier, !identifier.isEmpty {
        fields.append("identifier=\(sanitized(identifier))")
    }
    if let enabled = enabled {
        fields.append("enabled=\(enabled)")
    }

    if shouldPrintSemanticText(for: role) {
        if let title = stringValue(element, attribute: kAXTitleAttribute as CFString),
           !title.isEmpty {
            fields.append("title=\(sanitized(title))")
        }
        if let description = stringValue(element, attribute: kAXDescriptionAttribute as CFString),
           !description.isEmpty,
           description != stringValue(element, attribute: kAXTitleAttribute as CFString) {
            fields.append("description=\(sanitized(description))")
        }
    } else if role == (kAXWindowRole as String) {
        fields.append("title=<redacted-window-title>")
    }

    if let url = urlOnlyValue(element) {
        fields.append("url=\(sanitized(url))")
    }

    return fields.joined(separator: " ")
}

private func dumpTree(
    _ element: AXUIElement,
    depth: Int,
    prefix: String
) {
    guard depth <= maximumTreeDepth else {
        print("\(prefix)<maximum depth reached>")
        return
    }

    print("\(prefix)\(elementSummary(element))")

    let children = elementsValue(element, attribute: kAXChildrenAttribute as CFString)
    if children.count > maximumChildrenPerElement {
        print("\(prefix)  <children truncated: \(children.count) total>")
    }

    for child in children.prefix(maximumChildrenPerElement) {
        dumpTree(child, depth: depth + 1, prefix: prefix + "  ")
    }
}

private func requestedPID() -> pid_t? {
    let arguments = CommandLine.arguments
    guard let index = arguments.firstIndex(of: "--pid"),
          index + 1 < arguments.count,
          let parsed = Int32(arguments[index + 1]) else {
        return nil
    }
    return parsed
}

private func locateOrion() -> NSRunningApplication? {
    let running = NSWorkspace.shared.runningApplications

    if let pid = requestedPID() {
        return running.first { $0.processIdentifier == pid }
    }

    if let exact = running.first(where: { $0.localizedName == "Orion" }) {
        return exact
    }

    return running.first { application in
        let identifier = application.bundleIdentifier?.lowercased() ?? ""
        return identifier.contains("kagi") && application.activationPolicy == .regular
    }
}

guard AXIsProcessTrusted() else {
    fputs("ERROR: Accessibility permission is required before running this read-only probe.\n", stderr)
    exit(2)
}

guard let orion = locateOrion() else {
    fputs("ERROR: A running Orion application could not be located. Launch Orion and retry.\n", stderr)
    exit(3)
}

let applicationElement = AXUIElementCreateApplication(orion.processIdentifier)

print("=== ORION ACCESSIBILITY STRUCTURE ===")
print("pid=\(orion.processIdentifier)")
print("localizedName=\(orion.localizedName ?? "<unknown>")")
print("bundleIdentifier=\(orion.bundleIdentifier ?? "<unknown>")")
print("bundleURL=\(orion.bundleURL?.path ?? "<unknown>")")
print("maximumTreeDepth=\(maximumTreeDepth)")
print("values=URL-only; webpage/static text is not printed")
print("")

print("=== MENU BAR ===")
if let menuBar = copiedValue(
    applicationElement,
    attribute: kAXMenuBarAttribute as CFString
) as? AXUIElement {
    dumpTree(menuBar, depth: 0, prefix: "")
} else {
    print("<menu bar unavailable>")
}

print("")
print("=== WINDOWS ===")
let windows = elementsValue(applicationElement, attribute: kAXWindowsAttribute as CFString)
if windows.isEmpty {
    print("<no accessible windows>")
} else {
    for (index, window) in windows.enumerated() {
        print("--- window \(index + 1) ---")
        dumpTree(window, depth: 0, prefix: "")
    }
}
