//
//  ValidatedPlanTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct ValidatedPlanTests {
    /// T-P1-02 acceptance: the Phase-1 factory is the (currently)
    /// only way to produce a ValidatedPlan from a RawPlan. The
    /// private init means any attempt to call
    ///     ValidatedPlan(steps: ...)
    /// from outside the file is a compile-time error, which is the
    /// real test — there is no runtime expression that can violate
    /// it. Once T-P5-05 deletes phase1Allow, the only producer will
    /// be PlanValidator.
    @Test func phase1AllowWrapsRawPlanStepsVerbatim() {
        // swiftlint:disable:next force_unwrapping
        let url = URL(string: "https://youtube.com/")!
        let raw = RawPlan(steps: [
            PlanStep(action: .openURL(url)),
            PlanStep(action: .webEvaluate(script: "void 0;")),
        ])

        let validated = ValidatedPlan.phase1Allow(raw)

        #expect(validated.steps == raw.steps)
    }

    @Test func phase1AllowOnEmptyRawPlanProducesEmptyValidated() {
        let validated = ValidatedPlan.phase1Allow(RawPlan(steps: []))
        #expect(validated.steps.isEmpty)
    }

    @Test func safetyVerdictAllowExists() {
        // Smoke test that the Phase 1 stub exists and is Equatable.
        // Phase 5 adds .deny, .requireConfirm, .requireTouchID.
        let verdict = SafetyVerdict.allow
        #expect(verdict == .allow)
    }
}
