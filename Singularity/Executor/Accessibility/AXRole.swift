//
//  AXRole.swift
//  Singularity
//

import Foundation

/// A subset of Accessibility roles, with their underlying `AX…` string
/// constants. Adapters match elements by role (research brief §5);
/// `rawValue` is what the AX API actually reports.
enum AXRole: String {
    case button = "AXButton"
    case window = "AXWindow"
    case group = "AXGroup"
    case staticText = "AXStaticText"
    case menuItem = "AXMenuItem"
    case menuButton = "AXMenuButton"
    case toolbar = "AXToolbar"
    case textField = "AXTextField"
    case row = "AXRow"
    case cell = "AXCell"
    case image = "AXImage"
}
