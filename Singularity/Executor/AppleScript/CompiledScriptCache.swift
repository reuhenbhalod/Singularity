//
//  CompiledScriptCache.swift
//  Singularity
//

import Foundation

/// Compiles `NSAppleScript`s once and caches them for the session
/// (research brief §6 / T-P6-02). Compilation is the expensive part, so
/// repeated dispatches of the same hook reuse the compiled script.
///
/// `@MainActor` because `NSAppleScript` is not thread-safe and the
/// executor's AppleScript work is main-actor-confined.
@MainActor
final class CompiledScriptCache {
    private var cache: [String: NSAppleScript] = [:]

    /// The compiled script for `source`, compiling and caching on first
    /// use. Returns `nil` only if the source can't form a script at all.
    func script(for source: String) -> NSAppleScript? {
        if let cached = cache[source] { return cached }
        guard let script = NSAppleScript(source: source) else { return nil }
        script.compileAndReturnError(nil)  // compile now; run reports errors
        cache[source] = script
        return script
    }

    /// Number of scripts currently cached (for tests).
    var count: Int { cache.count }
}
