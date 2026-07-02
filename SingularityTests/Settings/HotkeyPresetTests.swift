//
//  HotkeyPresetTests.swift
//  SingularityTests
//

import Carbon.HIToolbox
import Testing

@testable import Singularity

struct HotkeyPresetTests {
    /// A known id maps to its preset; an unknown id falls back to ⌥Space.
    @Test func presetLookupFallsBackToOptionSpace() {
        #expect(HotkeyPreset.preset(id: "ctrl-space") == .controlSpace)
        #expect(HotkeyPreset.preset(id: "nonsense") == .optionSpace)
    }

    /// Each preset produces a combo with the expected modifiers.
    @Test func combosCarryExpectedModifiers() {
        #expect(HotkeyPreset.optionSpace.combo.modifiers == [.option])
        #expect(HotkeyPreset.controlSpace.combo.modifiers == [.control])
        #expect(HotkeyPreset.commandShiftSpace.combo.modifiers == [.command, .shift])
        #expect(HotkeyPreset.optionSpace.combo.keyCode == UInt32(kVK_Space))
    }

    /// The default settings id matches the default combo.
    @Test func defaultIdIsOptionSpace() {
        #expect(HotkeyPreset.preset(id: SettingsStore.Defaults.summonHotkeyID) == .optionSpace)
    }
}
