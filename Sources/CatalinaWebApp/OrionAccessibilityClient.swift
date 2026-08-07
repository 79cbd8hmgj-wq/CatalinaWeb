import ApplicationServices
import Foundation

protocol OrionAccessibilityControlling: AnyObject {
    func findMenuItem(path: [String], in application: AXUIElement) -> AXUIElement?
    func press(_ element: AXUIElement) -> Bool
    func stringValue(of element: AXUIElement, attribute: CFString) -> String?
    func setStringValue(_ value: String, on element: AXUIElement, attribute: CFString) -> Bool
    func windows(of application: AXUIElement) -> [AXUIElement]
}

final class SystemOrionAccessibilityClient: OrionAccessibilityControlling {
    func findMenuItem(path: [String], in application: AXUIElement) -> AXUIElement? {
        guard !path.isEmpty,
              let menuBar = elementValue(
                application,
                attribute: kAXMenuBarAttribute as CFString
              ) else {
            return nil
        }

        var searchRoots: [AXUIElement] = [menuBar]

        for (index, title) in path.enumerated() {
            var match: AXUIElement?
            for root in searchRoots {
                if let candidate = firstMenuDescendant(
                    of: root,
                    titled: title,
                    maximumDepth: 3
                ) {
                    match = candidate
                    break
                }
            }

            guard let matched = match else {
                return nil
            }

            if index == path.count - 1 {
                return matched
            }

            searchRoots = elementsValue(
                matched,
                attribute: kAXChildrenAttribute as CFString
            )
            if searchRoots.isEmpty {
                return nil
            }
        }

        return nil
    }

    func press(_ element: AXUIElement) -> Bool {
        AXUIElementPerformAction(
            element,
            kAXPressAction as CFString
        ) == .success
    }

    func stringValue(of element: AXUIElement, attribute: CFString) -> String? {
        copiedValue(element, attribute: attribute) as? String
    }

    func setStringValue(
        _ value: String,
        on element: AXUIElement,
        attribute: CFString
    ) -> Bool {
        AXUIElementSetAttributeValue(
            element,
            attribute,
            value as CFString
        ) == .success
    }

    func windows(of application: AXUIElement) -> [AXUIElement] {
        elementsValue(application, attribute: kAXWindowsAttribute as CFString)
    }

    private func firstMenuDescendant(
        of element: AXUIElement,
        titled title: String,
        maximumDepth: Int
    ) -> AXUIElement? {
        let role = stringValue(of: element, attribute: kAXRoleAttribute as CFString)
        let elementTitle = stringValue(of: element, attribute: kAXTitleAttribute as CFString)
        let validRole = role == (kAXMenuBarItemRole as String)
            || role == (kAXMenuItemRole as String)

        if validRole && elementTitle == title {
            return element
        }

        guard maximumDepth > 0 else {
            return nil
        }

        let children = elementsValue(
            element,
            attribute: kAXChildrenAttribute as CFString
        )
        for child in children {
            if let match = firstMenuDescendant(
                of: child,
                titled: title,
                maximumDepth: maximumDepth - 1
            ) {
                return match
            }
        }
        return nil
    }

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

    private func elementsValue(
        _ element: AXUIElement,
        attribute: CFString
    ) -> [AXUIElement] {
        copiedValue(element, attribute: attribute) as? [AXUIElement] ?? []
    }
}
