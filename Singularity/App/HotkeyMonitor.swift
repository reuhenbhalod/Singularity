//
//  HotkeyMonitor.swift
//  Singularity
//

import AppKit
import Carbon.HIToolbox
import os

/// Global hotkey monitor backed by Carbon's `RegisterEventHotKey`.
///
/// Why Carbon (legacy, deprecated since macOS 10.6): the Carbon path
/// requires no TCC permission, while `NSEvent.addGlobalMonitorForEvents`
/// needs Input Monitoring and `CGEventTap` needs Accessibility. Raycast
/// and Alfred use the same approach. See research brief §3.
@MainActor
final class HotkeyMonitor {
    typealias Handler = @MainActor () -> Void
    typealias Token = UInt32

    private struct Registration {
        let ref: EventHotKeyRef
        let handler: Handler
    }

    /// 'SING' four-char code that tags our hotkeys among any others
    /// registered in the same event target.
    private static let signature: OSType = {
        let chars = Array("SING".utf8)
        return (UInt32(chars[0]) << 24)
            | (UInt32(chars[1]) << 16)
            | (UInt32(chars[2]) << 8)
            | UInt32(chars[3])
    }()

    private var registrations: [Token: Registration] = [:]
    private var nextID: Token = 1
    private var eventHandler: EventHandlerRef?
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "hotkey")

    init() {
        installCarbonDispatcher()
    }

    deinit {
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        for reg in registrations.values {
            UnregisterEventHotKey(reg.ref)
        }
    }

    /// Registers a global hotkey with the given Carbon `keyCode` and
    /// `modifiers` mask. Returns a token for later `uninstall`, or `nil`
    /// if registration fails (e.g. another app owns that combo).
    func install(keyCode: UInt32, modifiers: UInt32, handler: @escaping Handler) -> Token? {
        let id = nextID
        nextID += 1
        let hotkeyID = EventHotKeyID(signature: Self.signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            logger.error("RegisterEventHotKey failed with status \(status)")
            return nil
        }
        registrations[id] = Registration(ref: ref, handler: handler)
        return id
    }

    func uninstall(_ token: Token) {
        guard let reg = registrations[token] else { return }
        UnregisterEventHotKey(reg.ref)
        registrations.removeValue(forKey: token)
    }

    private func installCarbonDispatcher() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let eventRef, let userData else { return noErr }
                var hkID = EventHotKeyID()
                let getStatus = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout.size(ofValue: hkID),
                    nil,
                    &hkID
                )
                guard getStatus == noErr else { return noErr }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userData).takeUnretainedValue()
                // Carbon hotkey events arrive on the main thread; safe to assume.
                MainActor.assumeIsolated {
                    monitor.registrations[hkID.id]?.handler()
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        if status != noErr {
            logger.error("InstallEventHandler failed with status \(status)")
        }
    }
}
