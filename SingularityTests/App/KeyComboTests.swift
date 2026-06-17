//
//  KeyComboTests.swift
//  SingularityTests
//

import Carbon.HIToolbox
import Foundation
import Testing

@testable import Singularity

struct KeyComboTests {
    @Test func defaultShellSummonIsOptionSpace() {
        let combo = KeyCombo.defaultShellSummon
        // kVK_Space is 49 (per Carbon.HIToolbox.Events).
        #expect(combo.keyCode == UInt32(kVK_Space))
        #expect(combo.keyCode == 49)
        #expect(combo.modifiers == [.option])
    }

    /// T-P0-04 acceptance: round-trip JSON encode/decode preserves the value.
    @Test func roundTripJSONPreservesKeyCodeAndModifiers() throws {
        let original = KeyCombo(keyCode: 49, modifiers: [.option])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyCombo.self, from: data)

        #expect(decoded == original)
        #expect(decoded.keyCode == 49)
        #expect(decoded.modifiers == [.option])
    }

    @Test func roundTripJSONWithMultipleModifiers() throws {
        let original = KeyCombo(
            keyCode: UInt32(kVK_F19),
            modifiers: [.command, .option, .control, .shift]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyCombo.self, from: data)

        #expect(decoded == original)
        #expect(decoded.modifiers.count == 4)
    }

    @Test func carbonModifierMaskCombinesBits() {
        let combo = KeyCombo(keyCode: 49, modifiers: [.option, .shift])
        let expected = UInt32(optionKey | shiftKey)
        #expect(combo.carbonModifierMask == expected)
    }

    @Test func carbonModifierMaskEmptyIsZero() {
        let combo = KeyCombo(keyCode: 49, modifiers: [])
        #expect(combo.carbonModifierMask == 0)
    }
}
