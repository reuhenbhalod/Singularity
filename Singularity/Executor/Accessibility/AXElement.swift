//
//  AXElement.swift
//  Singularity
//

import ApplicationServices

/// Thin Swift wrapper over a live `AXUIElement` (research brief §5).
/// Reading attributes and children is synchronous IPC into the target
/// app and requires Accessibility permission; without it, `children()`
/// throws `AXErrors.notAuthorized`.
@MainActor
struct AXElement: AXNode {
    let element: AXUIElement

    var roleString: String? { copyString(kAXRoleAttribute as CFString) }
    var title: String? { copyString(kAXTitleAttribute as CFString) }

    func children() throws -> [any AXNode] {
        guard let value = try copyAttribute(kAXChildrenAttribute as CFString) else { return [] }
        let elements = value as? [AXUIElement] ?? []
        return elements.map { AXElement(element: $0) }
    }

    func perform(_ action: AXAction) throws {
        let result = AXUIElementPerformAction(element, action.rawValue as CFString)
        if result != .success {
            throw AXErrors.from(result)
        }
    }

    // MARK: - Attribute helpers

    private func copyString(_ attribute: CFString) -> String? {
        (try? copyAttribute(attribute)) as? String
    }

    private func copyAttribute(_ attribute: CFString) throws -> Any? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        switch result {
        case .success:
            return value
        case .noValue, .attributeUnsupported:
            return nil
        default:
            throw AXErrors.from(result)
        }
    }
}
