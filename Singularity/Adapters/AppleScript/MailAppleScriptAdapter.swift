//
//  MailAppleScriptAdapter.swift
//  Singularity
//

import Foundation

/// Reads Mail via AppleScript (research brief §6) — more reliable than
/// the AX path for reading. Read-only in v1: drafting and sending need
/// recipient/body arguments the parameterless hook schema can't carry, so
/// they're deferred to a parameterized action (v1.1). Sending, when it
/// lands, is `.destructive`+ and gated by confirm + Touch ID.
struct MailAppleScriptAdapter: AppleScriptAdapter {
    let name = "mail"

    let scripts = [
        "unread_count": "tell application \"Mail\" to return unread count of inbox & \" unread\"",
        "latest_subject":
            "tell application \"Mail\"\n"
            + "set inboxMessages to messages of inbox\n"
            + "if (count of inboxMessages) is 0 then return \"Your inbox is empty\"\n"
            + "return \"latest: \" & (subject of item 1 of inboxMessages)\n"
            + "end tell",
    ]
}
