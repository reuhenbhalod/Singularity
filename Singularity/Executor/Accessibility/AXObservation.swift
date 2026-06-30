//
//  AXObservation.swift
//  Singularity
//

import ApplicationServices

/// Bridges an `AXObserver` (the C Accessibility-notification API) into a
/// Swift `AsyncStream` (research brief §5, T-P4-03). Adapters can `for
/// await` UI events — focus changes, window changes — instead of polling.
///
/// Cancelling the consuming task tears the observer down. Exercising it
/// needs a live app + Accessibility permission, so it is verified
/// manually (per the task's manual acceptance check).
@MainActor
enum AXObservation {
    /// Yields once each time `notification` fires on `element` for the
    /// app with `pid` (e.g. `kAXFocusedUIElementChangedNotification`).
    /// Finishes immediately if the observer can't be created.
    static func stream(
        pid: pid_t,
        element: AXUIElement,
        notification: String
    ) -> AsyncStream<Void> {
        AsyncStream { continuation in
            // A non-capturing literal closure forms a valid C function
            // pointer; it fires on the observer's run loop and yields one
            // event, recovering the continuation from the refcon.
            let callback: AXObserverCallback = { _, _, _, refcon in
                guard let refcon else { return }
                Unmanaged<AXContinuationBox>.fromOpaque(refcon)
                    .takeUnretainedValue()
                    .continuation.yield(())
            }

            var observer: AXObserver?
            guard AXObserverCreate(pid, callback, &observer) == .success,
                let observer
            else {
                continuation.finish()
                return
            }

            // Carry the continuation through the C callback's refcon.
            let box = AXContinuationBox(continuation)
            let refcon = Unmanaged.passRetained(box).toOpaque()

            guard
                AXObserverAddNotification(observer, element, notification as CFString, refcon)
                    == .success
            else {
                Unmanaged<AXContinuationBox>.fromOpaque(refcon).release()
                continuation.finish()
                return
            }

            // Capture the current (main) run loop so termination removes
            // the source from the same loop it was added to.
            let runLoop = CFRunLoopGetCurrent()
            let source = AXObserverGetRunLoopSource(observer)
            CFRunLoopAddSource(runLoop, source, .defaultMode)

            continuation.onTermination = { _ in
                AXObserverRemoveNotification(observer, element, notification as CFString)
                CFRunLoopRemoveSource(runLoop, source, .defaultMode)
                Unmanaged<AXContinuationBox>.fromOpaque(refcon).release()
            }
        }
    }
}

/// Boxes the stream continuation so it can ride through the C callback's
/// `refcon` pointer.
private final class AXContinuationBox {
    let continuation: AsyncStream<Void>.Continuation
    init(_ continuation: AsyncStream<Void>.Continuation) {
        self.continuation = continuation
    }
}
