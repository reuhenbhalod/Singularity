//
//  URLPolicy.swift
//  Singularity
//

import Foundation

/// The single decision point for whether a web pane may navigate to a
/// URL (research brief §11.4). Phase 3 rules: HTTPS only, no userinfo,
/// host on the `AllowedDomains` allowlist. The NSFW layer folds in
/// ahead of the allowlist in Phase 5.
struct URLPolicy {
    enum Reason: Equatable {
        case notHTTPS
        case userInfoPresent
        case hostNotAllowed
        case noHost
        case nsfwBlocked
    }

    enum Decision: Equatable {
        case allow
        case deny(reason: Reason)
    }

    private let allowed: AllowedDomains
    private let nsfw: NSFWBlocklist
    private let nsfwEnabled: Bool

    init(
        allowedDomains: AllowedDomains = AllowedDomains(),
        nsfw: NSFWBlocklist = NSFWBlocklist(),
        nsfwEnabled: Bool = true
    ) {
        allowed = allowedDomains
        self.nsfw = nsfw
        self.nsfwEnabled = nsfwEnabled
    }

    func evaluate(url: URL) -> Decision {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .deny(reason: .noHost)
        }
        guard components.scheme?.lowercased() == "https" else {
            return .deny(reason: .notHTTPS)
        }
        // Reject credentials-in-URL before even looking at the host, so
        // `https://user:pass@allowed-host/` can't sneak through.
        guard components.user == nil, components.password == nil else {
            return .deny(reason: .userInfoPresent)
        }
        guard let host = components.host?.lowercased() else {
            return .deny(reason: .noHost)
        }
        // NSFW check sits AHEAD of the allowlist and short-circuits: an
        // adult host is denied even if some adapter listed it. Turning
        // the filter off only skips this check — it never widens the
        // allowlist (brief §12.2 / US-NSFW-1).
        if nsfwEnabled, nsfw.contains(host) {
            return .deny(reason: .nsfwBlocked)
        }
        return allowed.contains(host) ? .allow : .deny(reason: .hostNotAllowed)
    }
}
