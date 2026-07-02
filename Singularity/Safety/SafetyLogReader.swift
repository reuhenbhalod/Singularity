//
//  SafetyLogReader.swift
//  Singularity
//

import Foundation
import OSLog

/// One rendered safety-log line for display.
struct SafetyLogLine: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let message: String

    static func == (lhs: SafetyLogLine, rhs: SafetyLogLine) -> Bool {
        lhs.date == rhs.date && lhs.message == rhs.message
    }
}

/// Reads the app's own safety-category OSLog entries back out (T-P7-20 /
/// T-P7-21). `OSLogStore(scope: .currentProcessIdentifier)` needs no
/// special entitlement to read the current process's logs. Filters to this
/// app's subsystem + the `safety` category over a recent window.
enum SafetyLogReader {
    static func recent(within seconds: TimeInterval = 3600, now: Date = Date()) -> [SafetyLogLine] {
        guard let store = try? OSLogStore(scope: .currentProcessIdentifier) else { return [] }
        let start = store.position(date: now.addingTimeInterval(-seconds))
        let predicate = NSPredicate(
            format: "subsystem == %@ AND category == %@",
            SafetyLog.subsystem, SafetyLog.category)
        guard let entries = try? store.getEntries(at: start, matching: predicate) else { return [] }
        return entries.compactMap { entry -> SafetyLogLine? in
            guard let log = entry as? OSLogEntryLog else { return nil }
            return SafetyLogLine(date: log.date, message: log.composedMessage)
        }
    }
}
