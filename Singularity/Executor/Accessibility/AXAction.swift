//
//  AXAction.swift
//  Singularity
//

import Foundation

/// Accessibility actions an element can perform, with their underlying
/// `AX…` string constants (research brief §5). `press` covers most
/// "click this control" cases.
enum AXAction: String {
    case press = "AXPress"
    case showMenu = "AXShowMenu"
    case increment = "AXIncrement"
    case decrement = "AXDecrement"
    case confirm = "AXConfirm"
    case cancel = "AXCancel"
}
