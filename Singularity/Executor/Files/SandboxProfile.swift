//
//  SandboxProfile.swift
//  Singularity
//

import Foundation

/// Generates the `sandbox-exec` profile for a lane-5 shell command (brief
/// §8): reads are allowed, writes are confined to the declared `scope`,
/// network is denied, and only a whitelist of common utilities may be
/// executed. Mirrors `SandboxProfile.sb` (kept as reference).
enum SandboxProfile {
    static func source(scope: URL) -> String {
        """
        (version 1)
        (deny default)
        (allow process-fork)
        (allow signal (target self))
        (allow sysctl-read)
        (allow mach-lookup)
        (allow file-read*)
        (allow file-write* (subpath \"\(scope.path)\"))
        (allow file-write-data
          (literal \"/dev/null\") (literal \"/dev/stdout\") (literal \"/dev/stderr\"))
        (deny network*)
        (allow process-exec
          (literal \"/bin/zsh\") (literal \"/bin/sh\") (literal \"/bin/bash\")
          (literal \"/bin/echo\") (literal \"/bin/ls\") (literal \"/bin/cat\")
          (literal \"/bin/cp\") (literal \"/bin/mv\") (literal \"/bin/pwd\")
          (literal \"/usr/bin/grep\") (literal \"/usr/bin/head\") (literal \"/usr/bin/tail\")
          (literal \"/usr/bin/wc\") (literal \"/usr/bin/sort\") (literal \"/usr/bin/find\")
          (literal \"/usr/bin/basename\") (literal \"/usr/bin/dirname\"))
        """
    }
}
