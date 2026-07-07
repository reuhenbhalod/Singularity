//
//  RoutineCommandTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

// MARK: - Parser (US-RT-1)

struct RoutineParserTests {
    @Test func parsesValidDefinition() {
        #expect(
            RoutineParser.parse("dev = open code; open terminal")
                == .definition(name: "dev", steps: ["open code", "open terminal"], overwrite: false))
    }

    @Test func lowercasesName() {
        guard case .definition(let name, _, _) = RoutineParser.parse("Dev = open code") else {
            Issue.record("expected a definition")
            return
        }
        #expect(name == "dev")
    }

    @Test func trailingOverwriteTokenIsStripped() {
        #expect(
            RoutineParser.parse("dev = open code overwrite")
                == .definition(name: "dev", steps: ["open code"], overwrite: true))
    }

    @Test func missingEqualsFails() {
        guard case .failure = RoutineParser.parse("dev open code") else {
            Issue.record("expected failure")
            return
        }
    }

    @Test func reservedNameFails() {
        guard case .failure = RoutineParser.parse("run = open code") else {
            Issue.record("expected failure")
            return
        }
    }

    @Test func invalidNameFails() {
        guard case .failure = RoutineParser.parse("9x = open code") else {
            Issue.record("expected failure")
            return
        }
    }

    @Test func emptyStepsFails() {
        guard case .failure = RoutineParser.parse("dev =    ") else {
            Issue.record("expected failure")
            return
        }
    }

    /// The Settings edit path (honorOverwriteToken: false) keeps a step that
    /// legitimately ends in the word "overwrite".
    @Test func editPathKeepsTrailingOverwriteWord() {
        #expect(
            RoutineParser.parse("dev = confirm overwrite", honorOverwriteToken: false)
                == .definition(name: "dev", steps: ["confirm overwrite"], overwrite: false))
    }
}

// MARK: - Resolver (US-RT-2 / US-RT-6)

struct RoutineResolverTests {
    private let resolver = RoutineResolver(routines: ["dev": ["a", "b"]])

    @Test func bareNameExpands() {
        #expect(resolver.resolve("dev") == .expanded(name: "dev", steps: ["a", "b"]))
    }

    @Test func bareNameIsCaseInsensitive() {
        #expect(resolver.resolve("DEV") == .expanded(name: "dev", steps: ["a", "b"]))
    }

    @Test func runNameExpands() {
        #expect(resolver.resolve("run dev") == .expanded(name: "dev", steps: ["a", "b"]))
    }

    @Test func runUnknownIsNotFound() {
        #expect(resolver.resolve("run nope") == .notFound(name: "nope"))
    }

    /// A sentence that merely contains the name is NOT an invocation.
    @Test func sentenceContainingNamePassesThrough() {
        #expect(resolver.resolve("play dev's newest video") == .passthrough)
    }

    @Test func unknownBareNamePassesThrough() {
        #expect(resolver.resolve("finder") == .passthrough)
    }
}

// MARK: - Command handler (US-RT-1/3/4/5)

@MainActor
struct RoutineCommandHandlerTests {
    private func store() -> RoutineStore {
        RoutineStore(url: FileManager.default.temporaryDirectory
            .appendingPathComponent("rt-\(UUID().uuidString).json"))
    }

    @Test func createsRoutine() async {
        let store = store()
        let handler = RoutineCommandHandler(store: store) { _, _ in }
        #expect(await handler.handle("routine dev = open code; open terminal"))
        #expect(await store.all().count == 1)
        #expect(await store.all().first?.steps.count == 2)
    }

    @Test func nonRoutineInputIsNotHandled() async {
        let handler = RoutineCommandHandler(store: store()) { _, _ in }
        #expect(await handler.handle("play some music") == false)
    }

    @Test func overwriteRequiresToken() async {
        let store = store()
        let handler = RoutineCommandHandler(store: store) { _, _ in }
        _ = await handler.handle("routine dev = a")
        // Without the token the existing routine is kept.
        _ = await handler.handle("routine dev = b; c")
        #expect(await store.all().first?.steps == ["a"])
        // With it, the routine is replaced.
        _ = await handler.handle("routine dev = b; c overwrite")
        #expect(await store.all().first?.steps == ["b", "c"])
    }

    @Test func deleteRequiresConfirm() async {
        let store = store()
        let handler = RoutineCommandHandler(store: store) { _, _ in }
        _ = await handler.handle("routine dev = a")
        _ = await handler.handle("routine delete dev")
        #expect(await store.all().count == 1)  // not yet
        _ = await handler.handle("confirm")
        #expect(await store.all().isEmpty)  // now
    }

    @Test func deleteCancelledByNonConfirm() async {
        let store = store()
        let handler = RoutineCommandHandler(store: store) { _, _ in }
        _ = await handler.handle("routine dev = a")
        _ = await handler.handle("routine delete dev")
        _ = await handler.handle("actually no")
        #expect(await store.all().count == 1)
    }
}
