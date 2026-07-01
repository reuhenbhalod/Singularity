//
//  NSFWBlocklist.swift
//  Singularity
//

import Foundation

/// Adult-content host set, loaded once at app start from the bundled
/// `nsfw-blocklist.txt` (brief §12.2). `URLPolicy` consults it ahead of
/// the allowlist when the NSFW filter is on. Matching is host-based and
/// subdomain-aware (`www.pornhub.com` matches `pornhub.com`).
///
/// The bundled list is a starter set; maintainers regenerate the full
/// list from StevenBlack/hosts via `Scripts/refresh-nsfw-list.sh`.
struct NSFWBlocklist {
    let hosts: Set<String>

    /// Injects a host set directly (tests).
    init(hosts: Set<String>) {
        self.hosts = hosts
    }

    /// Loads from the bundled `nsfw-blocklist.txt`; an empty set (filter
    /// effectively off) if the resource is missing.
    init(bundle: Bundle = .main) {
        hosts = Self.loadHosts(from: bundle)
    }

    /// Whether `host` (or a parent domain of it) is blocked.
    func contains(_ host: String) -> Bool {
        var labels = host.lowercased().split(separator: ".").map(String.init)
        while labels.count >= 2 {
            if hosts.contains(labels.joined(separator: ".")) { return true }
            labels.removeFirst()
        }
        return false
    }

    static func loadHosts(from bundle: Bundle) -> Set<String> {
        guard let url = bundle.url(forResource: "nsfw-blocklist", withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return []
        }
        return parse(text)
    }

    /// Parses one-host-per-line text, ignoring blanks and `#` comments.
    static func parse(_ text: String) -> Set<String> {
        var out: Set<String> = []
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces).lowercased()
            if line.isEmpty || line.hasPrefix("#") { continue }
            out.insert(line)
        }
        return out
    }
}
