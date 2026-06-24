//
//  WebHookJSTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct WebHookJSTests {
    /// The shared library defines every reusable helper an adapter
    /// composes into its hooks.
    @Test func libraryDefinesAllHelpers() {
        let lib = WebHookJS.library
        #expect(lib.contains("function __sgl_waitForSelector"))
        #expect(lib.contains("function __sgl_firstLinkMatching"))
        #expect(lib.contains("function __sgl_clickByText"))
        #expect(lib.contains("function __sgl_dismissConsent"))
    }

    /// `firstLinkMatching` selects by the stable shape of a link's href
    /// (a `MutationObserver` + auto-scroll wait), the durable replacement
    /// for id/class-based selection.
    @Test func firstLinkMatchingUsesObserverAndScroll() {
        let lib = WebHookJS.library
        #expect(lib.contains("MutationObserver"))
        #expect(lib.contains("a[href]"))
        // Nudges lazy-loaded lists into rendering.
        #expect(lib.contains("window.scrollBy"))
    }

    /// `jsStringLiteral` produces a quoted, escaped JS string literal so a
    /// value can never break out of the surrounding script.
    @Test func jsStringLiteralQuotesAndEscapes() {
        #expect(WebHookJS.jsStringLiteral("MrBeast") == "\"MrBeast\"")
        #expect(WebHookJS.jsStringLiteral("/watch?v=") == "\"/watch?v=\"")

        // A value containing a quote is escaped (no raw breakout).
        let tricky = WebHookJS.jsStringLiteral("foo\"; alert(1);//")
        #expect(tricky.contains("\\\""))  // the escaped quote is present…
        #expect(!tricky.contains("foo\";"))  // …so the raw breakout is not
    }
}
