//
//  AXErrors.swift
//  Singularity
//

import ApplicationServices

/// Typed errors for Accessibility (AX) operations, mapped from the C
/// `AXError` result codes (research brief §5). The C API returns an
/// `AXError` from nearly every call; this turns the codes we care about
/// into something Swift code can `catch` on.
enum AXErrors: Error, Equatable {
    /// Accessibility isn't granted (or the AX API is disabled).
    case notAuthorized
    /// The element, attribute, or value doesn't exist / is stale.
    case elementUnavailable
    /// The element doesn't support the requested action.
    case actionUnsupported
    /// The app couldn't service the request (busy, IPC failed).
    case cannotComplete
    /// Any other non-success code.
    case failure(code: Int)

    static func from(_ error: AXError) -> AXErrors {
        switch error {
        case .apiDisabled, .notImplemented:
            return .notAuthorized
        case .actionUnsupported:
            return .actionUnsupported
        case .attributeUnsupported, .parameterizedAttributeUnsupported, .noValue, .invalidUIElement:
            return .elementUnavailable
        case .cannotComplete:
            return .cannotComplete
        default:
            return .failure(code: Int(error.rawValue))
        }
    }
}
