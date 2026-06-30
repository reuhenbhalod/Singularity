//
//  ShellStyle.swift
//  Singularity
//

import SwiftUI

/// Shared visual language for the shell — one place for the palette,
/// type tiers, and metrics so the command line, log, compositor, and
/// pane chrome stay consistent. Kept intentionally small: a handful of
/// tokens, not a framework.
enum ShellStyle {
    /// Single accent, used sparingly (focused prompt, command marker).
    static let accent = Color(red: 0.40, green: 0.62, blue: 1.0)

    /// Amber, for non-blocking alerts (e.g. a revoked-permission banner).
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.30)

    // Text tiers (on the dark, translucent shell background).
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.30)

    // Surfaces and lines.
    static let surface = Color.white.opacity(0.05)
    static let surfaceStrong = Color.white.opacity(0.09)
    static let hairline = Color.white.opacity(0.08)

    static let cornerRadius: CGFloat = 10
}
