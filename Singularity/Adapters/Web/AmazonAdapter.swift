//
//  AmazonAdapter.swift
//  Singularity
//

import Foundation

/// Amazon checkout adapter (brief §11.2 / `Singularity.md` §6). The
/// purchase flow is the extreme safety case: **two hard confirm stops** —
/// one before add-to-cart, one before placing the order — and the second
/// carries `.spend` risk, so it also requires Touch ID. Neither stop
/// auto-proceeds, regardless of planner confidence.
///
/// Structural for now: it declares the two-stop previews and the risk the
/// checkout gates apply. The `place_order` action that drives an actual
/// checkout (and this adapter's registration) lands with the executor
/// work that can mutate a cart — deliberately gated behind the confirm +
/// Touch ID gates built in Phase 5.
struct AmazonAdapter: WebAdapter {
    let allowedHosts = [
        "amazon.com",
        "www.amazon.com",
        "smile.amazon.com",
    ]

    let dataStoreIdentifier =
        UUID(uuidString: "E7A1B2C3-D4E5-4F6A-8B9C-0D1E2F3A4B5C") ?? UUID()

    /// Stop 1: adding to cart is reversible, so it needs only a confirm.
    static func addToCartPreview(item: String) -> ConfirmPreview {
        ConfirmPreview(title: "Add to cart", detail: "Add “\(item)” to your Amazon cart?")
    }

    /// Stop 2: placing the order spends money — `.spend` risk (Touch ID +
    /// confirm), never auto-proceeding.
    static func placeOrderPreview(item: String, total: String) -> ConfirmPreview {
        ConfirmPreview(title: "Place order", detail: "\(item) — \(total) to your default address")
    }

    static let placeOrderRisk: RiskClass = .spend
}
