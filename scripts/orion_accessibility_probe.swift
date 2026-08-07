import AppKit
import ApplicationServices
import Foundation

private let maximumTreeDepth = 8
private let maximumChildrenPerElement = 80
private let webAreaRole = "AXWebArea"
private let profileManagerTextAllowlist: Set<String> = [
    "Profiles",
    "Profile",
    "Primary",
    "CatalinaWeb",
    "Open Windows",
    "Is Default",
    "Synced",
    "New Profile...",
    "New Profile…",
    "Manage Profiles...",
    "Manage Profiles…"
]

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

private func attributeNames(of element: AXUIElement) -> [String] {
    var rawNames: CFArray?
    let error = AXUIElementCopyAttributeNames(element, &rawNames)
    guard error == .success, let resolvedNames = rawNames else {
        return []
    }
    return resolvedNames as? [String] ?? []
}

private func actionNames(of element: AXUIElement) -> [String] {
    var rawNames: CFArray?
    let error = AXUIElementCopyActionNames(element, &rawNames)
    guard error == .success, let resolvedNames = rawNames else {
        return []
    }
    return resolvedNames as? [String] ?? []
}

private func attributeIsSettable(
    _ element: AXUIElement,
    attribute: CFString
) -> Bool? {
    var settable = DarwinBoolean(false)
    let error = AXUIElementIsAttributeSettable(element, attribute, &settable)
    guard error == .success else {
        return nil
    }
    return settable.boolValue
}

private func urlString(_ raw: String?) -> String? {
    guard let raw = raw,
          let url = URL(string: raw),
          let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https" else {
        return nil
    }
    return raw
}

private func urlOnlyValue(_ element: AXUIElement) -> String? {
    urlString(stringValue(element, attribute: kAXValueAttribute as CFString))
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

private func firstDescendant(
    of element: AXUIElement,
    title: String,
    maximumDepth: Int
) -> AXUIElement? {
    if stringValue(element, attribute: kAXTitleAttribute as CFString) == title {
        return element
    }
    guard maximumDepth > 0 else {
        return nil
    }
    for child in elementsValue(element, attribute: kAXChildrenAttribute as CFString) {
        if let match = firstDescendant(
            of: child,
            title: title,
            maximumDepth: maximumDepth - 1
        ) {
            return match
        }
    }
    return nil
}

private func descendants(
    of element: AXUIElement,
    role expectedRole: String,
    maximumDepth: Int
) -> [AXUIElement] {
    guard maximumDepth >= 0 else {
        return []
    }

    var matches: [AXUIElement] = []
    let role = stringValue(element, attribute: kAXRoleAttribute as CFString)
    if role == expectedRole {
        matches.append(element)
    }

    guard maximumDepth > 0, role != webAreaRole else {
        return matches
    }

    for child in elementsValue(element, attribute: kAXChildrenAttribute as CFString) {
        matches.append(contentsOf: descendants(
            of: child,
            role: expectedRole,
            maximumDepth: maximumDepth - 1
        ))
    }
    return matches
}

private func firstURLBearingDescendant(
    of element: AXUIElement,
    maximumDepth: Int
) -> String? {
    if let url = urlOnlyValue(element) {
        return url
    }
    guard maximumDepth > 0 else {
        return nil
    }
    let role = stringValue(element, attribute: kAXRoleAttribute as CFString)
    guard role != webAreaRole else {
        return nil
    }
    for child in elementsValue(element, attribute: kAXChildrenAttribute as CFString) {
        if let url = firstURLBearingDescendant(
            of: child,
            maximumDepth: maximumDepth - 1
        ) {
            return url
        }
    }
    return nil
}

private func profileSemanticMarker(_ raw: String?) -> String? {
    guard let raw = raw else {
        return nil
    }
    let lowered = raw.lowercased()
    if lowered.contains("catalinaweb") {
        return "CatalinaWeb"
    }
    if lowered == "primary" || (lowered.contains("primary") && lowered.contains("profile")) {
        return "Primary"
    }
    if lowered.contains("profile") {
        return "profile-related"
    }
    return nil
}

private func semanticProfileMarker(of element: AXUIElement) -> String? {
    let attributes: [CFString] = [
        kAXTitleAttribute as CFString,
        kAXDescriptionAttribute as CFString,
        kAXHelpAttribute as CFString,
        kAXValueAttribute as CFString
    ]
    for attribute in attributes {
        if let marker = profileSemanticMarker(stringValue(element, attribute: attribute)) {
            return marker
        }
    }
    return nil
}

private func exactProfileName(in element: AXUIElement, maximumDepth: Int) -> String? {
    let values: [String?] = [
        stringValue(element, attribute: kAXTitleAttribute as CFString),
        stringValue(element, attribute: kAXDescriptionAttribute as CFString),
        stringValue(element, attribute: kAXValueAttribute as CFString)
    ]
    for raw in values {
        if raw == "CatalinaWeb" || raw == "Primary" {
            return raw
        }
    }

    guard maximumDepth > 0 else {
        return nil
    }
    let role = stringValue(element, attribute: kAXRoleAttribute as CFString)
    guard role != webAreaRole else {
        return nil
    }
    for child in elementsValue(element, attribute: kAXChildrenAttribute as CFString) {
        if let name = exactProfileName(in: child, maximumDepth: maximumDepth - 1) {
            return name
        }
    }
    return nil
}

private func numericValues(in element: AXUIElement, maximumDepth: Int) -> [String] {
    var result: [String] = []
    if let raw = stringValue(element, attribute: kAXValueAttribute as CFString) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if Int(trimmed) != nil {
            result.append(trimmed)
        }
    }

    guard maximumDepth > 0 else {
        return result
    }
    let role = stringValue(element, attribute: kAXRoleAttribute as CFString)
    guard role != webAreaRole else {
        return result
    }
    for child in elementsValue(element, attribute: kAXChildrenAttribute as CFString) {
        result.append(contentsOf: numericValues(
            in: child,
            maximumDepth: maximumDepth - 1
        ))
    }
    return result
}

private func printElementList(
    label: String,
    elements: [AXUIElement]
) {
    print("\(label).count=\(elements.count)")
    for (index, element) in elements.prefix(maximumChildrenPerElement).enumerated() {
        print("\(label)[\(index)]=\(elementSummary(element))")
    }
}

private func dumpProfilesDetail(menuBar: AXUIElement) {
    print("=== PROFILES DETAIL ===")

    guard let profilesItem = firstDescendant(
        of: menuBar,
        title: "Profiles",
        maximumDepth: 4
    ) else {
        print("profilesItem=<not found>")
        return
    }

    print("profilesItem=\(elementSummary(profilesItem))")
    print("profilesItem.attributes=\(attributeNames(of: profilesItem).sorted().joined(separator: ","))")
    print("profilesItem.actions=\(actionNames(of: profilesItem).sorted().joined(separator: ","))")

    let itemChildren = elementsValue(
        profilesItem,
        attribute: kAXChildrenAttribute as CFString
    )
    let itemVisibleChildren = elementsValue(
        profilesItem,
        attribute: kAXVisibleChildrenAttribute as CFString
    )
    printElementList(label: "profilesItem.children", elements: itemChildren)
    printElementList(label: "profilesItem.visibleChildren", elements: itemVisibleChildren)

    guard let submenu = itemChildren.first(where: { child in
        stringValue(child, attribute: kAXRoleAttribute as CFString) == (kAXMenuRole as String)
    }) else {
        print("profilesSubmenu=<not found>")
        return
    }

    print("profilesSubmenu=\(elementSummary(submenu))")
    print("profilesSubmenu.attributes=\(attributeNames(of: submenu).sorted().joined(separator: ","))")
    print("profilesSubmenu.actions=\(actionNames(of: submenu).sorted().joined(separator: ","))")

    let submenuChildren = elementsValue(
        submenu,
        attribute: kAXChildrenAttribute as CFString
    )
    let submenuVisibleChildren = elementsValue(
        submenu,
        attribute: kAXVisibleChildrenAttribute as CFString
    )
    printElementList(label: "profilesSubmenu.children", elements: submenuChildren)
    printElementList(label: "profilesSubmenu.visibleChildren", elements: submenuVisibleChildren)
}

private func allowlistedProfileManagerText(
    _ element: AXUIElement,
    attribute: CFString
) -> String? {
    guard let raw = stringValue(element, attribute: attribute),
          profileManagerTextAllowlist.contains(raw) else {
        return nil
    }
    return raw
}

private func profileManagerElementSummary(_ element: AXUIElement) -> String {
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

    if let title = allowlistedProfileManagerText(
        element,
        attribute: kAXTitleAttribute as CFString
    ) {
        fields.append("title=\(sanitized(title))")
    }
    if let description = allowlistedProfileManagerText(
        element,
        attribute: kAXDescriptionAttribute as CFString
    ) {
        fields.append("description=\(sanitized(description))")
    }
    if let value = allowlistedProfileManagerText(
        element,
        attribute: kAXValueAttribute as CFString
    ) {
        fields.append("value=\(sanitized(value))")
    } else if let rawValue = stringValue(element, attribute: kAXValueAttribute as CFString) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if Int(trimmed) != nil {
            fields.append("numericValue=\(trimmed)")
        } else if let url = urlString(rawValue) {
            fields.append("url=\(sanitized(url))")
        }
    }

    let actions = actionNames(of: element).sorted()
    if !actions.isEmpty {
        fields.append("actions=\(actions.joined(separator: ","))")
    }

    return fields.joined(separator: " ")
}

private func dumpProfileManagerTree(
    _ element: AXUIElement,
    depth: Int,
    prefix: String
) {
    guard depth <= maximumTreeDepth else {
        print("\(prefix)<maximum depth reached>")
        return
    }

    let role = stringValue(element, attribute: kAXRoleAttribute as CFString)
    if role == webAreaRole {
        print("\(prefix)<web area omitted>")
        return
    }

    print("\(prefix)\(profileManagerElementSummary(element))")

    let children = elementsValue(element, attribute: kAXChildrenAttribute as CFString)
    if children.count > maximumChildrenPerElement {
        print("\(prefix)  <children truncated: \(children.count) total>")
    }

    for child in children.prefix(maximumChildrenPerElement) {
        dumpProfileManagerTree(child, depth: depth + 1, prefix: prefix + "  ")
    }
}

private func dumpProfileManagerSelectionEvidence(_ window: AXUIElement) {
    let outlines = descendants(
        of: window,
        role: kAXOutlineRole as String,
        maximumDepth: maximumTreeDepth
    )
    guard let profileOutline = outlines.first(where: { outline in
        exactProfileName(in: outline, maximumDepth: 4) == "Primary"
            && descendants(
                of: outline,
                role: kAXRowRole as String,
                maximumDepth: 3
            ).contains(where: { row in
                exactProfileName(in: row, maximumDepth: 3) == "CatalinaWeb"
            })
    }) else {
        print("profileOutline=<not found>")
        return
    }

    print("profileOutline.attributes=\(attributeNames(of: profileOutline).sorted().joined(separator: ","))")
    print("profileOutline.actions=\(actionNames(of: profileOutline).sorted().joined(separator: ","))")
    let selectedRows = elementsValue(
        profileOutline,
        attribute: kAXSelectedRowsAttribute as CFString
    )
    print("profileOutline.selectedRows.count=\(selectedRows.count)")
    if let settable = attributeIsSettable(
        profileOutline,
        attribute: kAXSelectedRowsAttribute as CFString
    ) {
        print("profileOutline.selectedRows.settable=\(settable)")
    }

    let rows = descendants(
        of: profileOutline,
        role: kAXRowRole as String,
        maximumDepth: 3
    )
    for row in rows {
        guard let name = exactProfileName(in: row, maximumDepth: 3) else {
            continue
        }
        print("profileRow[\(name)].attributes=\(attributeNames(of: row).sorted().joined(separator: ","))")
        print("profileRow[\(name)].actions=\(actionNames(of: row).sorted().joined(separator: ","))")
        if let selected = boolValue(row, attribute: kAXSelectedAttribute as CFString) {
            print("profileRow[\(name)].selected=\(selected)")
        }
        if let settable = attributeIsSettable(
            row,
            attribute: kAXSelectedAttribute as CFString
        ) {
            print("profileRow[\(name)].selected.settable=\(settable)")
        }
        let numbers = numericValues(in: row, maximumDepth: 3)
        print("profileRow[\(name)].numericValues=\(numbers.joined(separator: ","))")
    }
}

private func dumpProfileManagerDetail(application: AXUIElement) {
    print("=== PROFILE MANAGER DETAIL ===")

    if let focusedWindow = elementValue(
        application,
        attribute: kAXFocusedWindowAttribute as CFString
    ) {
        print("focusedWindow=\(profileManagerElementSummary(focusedWindow))")
    } else {
        print("focusedWindow=<unavailable>")
    }

    if let mainWindow = elementValue(
        application,
        attribute: kAXMainWindowAttribute as CFString
    ) {
        print("mainWindow=\(profileManagerElementSummary(mainWindow))")
    } else {
        print("mainWindow=<unavailable>")
    }

    let windows = elementsValue(application, attribute: kAXWindowsAttribute as CFString)
    print("windows.count=\(windows.count)")

    var foundProfileManager = false
    for (index, window) in windows.enumerated() {
        let rawTitle = stringValue(window, attribute: kAXTitleAttribute as CFString)
        let isProfileManager = rawTitle == "Profiles"
        print("--- window \(index + 1) profileManager=\(isProfileManager) ---")
        dumpProfileManagerTree(window, depth: 0, prefix: "")
        if isProfileManager {
            foundProfileManager = true
            dumpProfileManagerSelectionEvidence(window)
        }
    }

    if !foundProfileManager {
        print("profileManager=<not found; open Orion Preferences > General > Manage Profiles and retry>")
    }
}

private func profileSelectorCandidateSummary(_ element: AXUIElement) -> String {
    var fields: [String] = []
    fields.append("role=\(stringValue(element, attribute: kAXRoleAttribute as CFString) ?? "<none>")")
    if let identifier = stringValue(element, attribute: kAXIdentifierAttribute as CFString),
       !identifier.isEmpty {
        fields.append("identifier=\(sanitized(identifier))")
    }

    let semanticAttributes: [(String, CFString)] = [
        ("title", kAXTitleAttribute as CFString),
        ("description", kAXDescriptionAttribute as CFString),
        ("help", kAXHelpAttribute as CFString),
        ("value", kAXValueAttribute as CFString)
    ]
    for pair in semanticAttributes {
        if let marker = profileSemanticMarker(stringValue(element, attribute: pair.1)) {
            fields.append("\(pair.0)=\(marker)")
        }
    }

    let actions = actionNames(of: element).sorted()
    if !actions.isEmpty {
        fields.append("actions=\(actions.joined(separator: ","))")
    }
    return fields.joined(separator: " ")
}

private func dumpProfileSelectorDetail(application: AXUIElement) {
    print("=== PROFILE SELECTOR DETAIL ===")
    let windows = elementsValue(application, attribute: kAXWindowsAttribute as CFString)
    print("windows.count=\(windows.count)")

    var browserCandidateCount = 0
    for (index, window) in windows.enumerated() {
        guard let currentURL = firstURLBearingDescendant(
            of: window,
            maximumDepth: maximumTreeDepth
        ) else {
            continue
        }
        browserCandidateCount += 1
        print("--- browserCandidate \(browserCandidateCount) windowIndex=\(index + 1) ---")
        print("currentURL=\(sanitized(currentURL))")

        let toolbars = descendants(
            of: window,
            role: kAXToolbarRole as String,
            maximumDepth: maximumTreeDepth
        )
        var popupCandidates: [AXUIElement] = []
        for toolbar in toolbars {
            popupCandidates.append(contentsOf: descendants(
                of: toolbar,
                role: kAXPopUpButtonRole as String,
                maximumDepth: 5
            ))
        }
        print("popupCandidates.count=\(popupCandidates.count)")
        for (popupIndex, popup) in popupCandidates.enumerated() {
            print("popup[\(popupIndex)]=\(profileSelectorCandidateSummary(popup))")
            print("popup[\(popupIndex)].attributes=\(attributeNames(of: popup).sorted().joined(separator: ","))")
            let children = elementsValue(popup, attribute: kAXChildrenAttribute as CFString)
            let visibleChildren = elementsValue(
                popup,
                attribute: kAXVisibleChildrenAttribute as CFString
            )
            print("popup[\(popupIndex)].children.count=\(children.count)")
            print("popup[\(popupIndex)].visibleChildren.count=\(visibleChildren.count)")
        }
    }
    print("browserCandidates.count=\(browserCandidateCount)")

    let menuItems = descendants(
        of: application,
        role: kAXMenuItemRole as String,
        maximumDepth: maximumTreeDepth + 2
    )
    var profileMenuMatchCount = 0
    for item in menuItems {
        guard let marker = semanticProfileMarker(of: item),
              marker == "CatalinaWeb" || marker == "Primary" else {
            continue
        }
        profileMenuMatchCount += 1
        print("profileMenuItem[\(profileMenuMatchCount)]=\(profileSelectorCandidateSummary(item))")
        print("profileMenuItem[\(profileMenuMatchCount)].attributes=\(attributeNames(of: item).sorted().joined(separator: ","))")
    }
    print("profileMenuItems.count=\(profileMenuMatchCount)")
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

if CommandLine.arguments.contains("--profile-manager-detail") {
    dumpProfileManagerDetail(application: applicationElement)
    exit(0)
}

if CommandLine.arguments.contains("--profile-selector-detail") {
    dumpProfileSelectorDetail(application: applicationElement)
    exit(0)
}

guard let menuBar = elementValue(
    applicationElement,
    attribute: kAXMenuBarAttribute as CFString
) else {
    print("=== MENU BAR ===")
    print("<menu bar unavailable>")
    exit(4)
}

if CommandLine.arguments.contains("--profiles-detail") {
    dumpProfilesDetail(menuBar: menuBar)
    exit(0)
}

print("=== MENU BAR ===")
dumpTree(menuBar, depth: 0, prefix: "")

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
