//
//  FilePathValidator.swift
//  Singularity
//

import Foundation

/// Validates a file path before any file operation runs (brief §11.3 /
/// T-P6-09): it expands `~`, standardizes `..`/`.`, resolves symlinks,
/// and confirms the result stays inside the user's home directory and out
/// of sensitive subtrees. Symlink escapes and `..` traversal that resolve
/// outside the scope are rejected.
struct FilePathValidator {
    enum Outcome: Equatable {
        case ok(URL)
        case rejected(reason: String)
    }

    private let home: URL
    /// First-level subtrees under home that are always off-limits.
    private let forbidden: Set<String>

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home.standardizedFileURL.resolvingSymlinksInPath()
        self.forbidden = ["Library", ".ssh", ".aws", ".gnupg", ".config"]
    }

    func validate(_ path: String) -> Outcome {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
            .standardizedFileURL
            .resolvingSymlinksInPath()

        let target = url.path
        let root = home.path
        guard target == root || target.hasPrefix(root + "/") else {
            return .rejected(reason: "\(path) is outside your home folder")
        }

        let relative = target.dropFirst(root.count).drop(while: { $0 == "/" })
        let firstComponent = relative.split(separator: "/").first.map(String.init) ?? ""
        if forbidden.contains(firstComponent) {
            return .rejected(reason: "\(path) is in a protected folder (~/\(firstComponent))")
        }
        return .ok(url)
    }
}
