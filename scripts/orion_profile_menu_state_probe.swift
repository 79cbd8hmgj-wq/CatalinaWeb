import AppKit
import ApplicationServices
import Foundation

private let maximumDepth = 10
private let webAreaRole = "AXWebArea"
private let axSelectedAttribute = "AXSelected" as CFString
private let axMenuItemMarkCharAttribute = "AXMenuItemMarkChar" as CFString
private let axMenuItemPrimaryUIElementAttribute = "AXMenuItemPrimaryUIElement" as CFString
private let axParentAttribute = "AXParent" as CFString

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

private func elementValue(
    _ element: AXUIElement,
    attribute: CFString
) -> AXUIElement? {
    guard let rawValue = copiedValue(element, attribute: attribute),
          CFGetTypeID(rawValue) == AXUIElementGetTypeID() else {
        return nil
    }
    return unsafeBitCast(rawValue, to: AXUIElement.self)
}

private func elementsValue(
    _ element: AXUIElement,
    attribute: CFString
) -> [AXUIElement] {
    copiedValue(element, attribute: attribute) as? [AXUIElement] ?? []
}

private func actionNames(of element: AXUIElement) -> [String] {
    var rawNames: CFArray?
    let error = AXUIElementCopyActionNames(element, &rawNames)
    guard error == .success, let resolvedNames = rawNames else {
        return []
    }
    return resolvedNames as? [String] ?? []
}

private func exactProfileName(_ element: AXUIElement) -> String? {
    let attributes: [CFString] = [
        kAXTitleAttribute as CFString,
        kAXDescriptionAttribute as CFString,
        kAXValueAttribute as CFString
    ]
    for attribute in attributes {
        guard let raw = stringValue(element, attribute: attribute) else {
            continue
        }
        if raw == "CatalinaWeb" || raw == "Primary" {
            return raw
        }
    }
    return nil
}

private func safeElementSummary(_ element: AXUIElement?) -> String {
    guard let element = element else {
        return "<none>"
    }

    var fields: [String] = []
    fields.append("role=\(stringValue(element, attribute: kAXRoleAttribute as CFString) ?? "<none>")")

    if let identifier = stringValue(element, attribute: kAXIdentifierAttribute as CFString),
       !identifier.isEmpty {
        fields.append("identifier=\(identifier)")
    }
    if let profileName = exactProfileName(element) {
        fields.append("profile=\(profileName)")
    }
    return fields.joined(separator: " ")
}

private func matchingProfileMenuItems(
    in element: AXUIElement,
    depth: Int
) -> [AXUIElement] {
    guard depth <= maximumDepth else {
        return []
    }

    let role = stringValue(element, attribute: kAXRoleAttribute as CFString)
    if role == webAreaRole {
        return []
    }

    var matches: [AXUIElement] = []
    if role == (kAXMenuItemRole as String), exactProfileName(element) != nil {
        matches.append(element)
    }

    for child in elementsValue(element, attribute: kAXChildrenAttribute as CFString) {
        matches.append(contentsOf: matchingProfileMenuItems(
            in: child,
            depth: depth + 1
        ))
    }
    return matches
}

private func printItem(_ item: AXUIElement, index: Int) {
    let profileName = exactProfileName(item) ?? "<unknown>"
    let identifier = stringValue(item, attribute: kAXIdentifierAttribute as CFString) ?? "<none>"
    let selected = boolValue(item, attribute: axSelectedAttribute)
    let mark = stringValue(item, attribute: axMenuItemMarkCharAttribute)
    let actions = actionNames(of: item).sorted()
    let primary = elementValue(item, attribute: axMenuItemPrimaryUIElementAttribute)
    let parent = elementValue(item, attribute: axParentAttribute)
    let grandparent = parent.flatMap { elementValue($0, attribute: axParentAttribute) }

    print("--- profileMenuItem \(index) ---")
    print("profile=\(profileName)")
    print("identifier=\(identifier)")
    if let selected = selected {
        print("selected=\(selected)")
    } else {
        print("selected=<unavailable>")
    }
    print("markPresent=\((mark ?? "").isEmpty == false)")
    print("actions=\(actions.joined(separator: ","))")
    print("primaryUI=\(safeElementSummary(primary))")
    print("parent=\(safeElementSummary(parent))")
    print("grandparent=\(safeElementSummary(grandparent))")
}

private func locateOrion() -> NSRunningApplication? {
    let running = NSWorkspace.shared.runningApplications
    if let exact = running.first(where: { $0.localizedName == "Orion" }) {
        return exact
    }
    return running.first { application in
        let identifier = application.bundleIdentifier?.lowercased() ?? ""
        return identifier.contains("kagi") && application.activationPolicy == .regular
    }
}

guard AXIsProcessTrusted() else {
    fputs("ERROR: Accessibility permission is required.\n", stderr)
    exit(2)
}

guard let orion = locateOrion() else {
    fputs("ERROR: A running Orion application could not be located.\n", stderr)
    exit(3)
}

let application = AXUIElementCreateApplication(orion.processIdentifier)
let items = matchingProfileMenuItems(in: application, depth: 0)

print("=== ORION PROFILE MENU STATE ===")
print("pid=\(orion.processIdentifier)")
print("bundleIdentifier=\(orion.bundleIdentifier ?? "<unknown>")")
print("matchingItems.count=\(items.count)")

for (index, item) in items.enumerated() {
    printItem(item, index: index + 1)
}
