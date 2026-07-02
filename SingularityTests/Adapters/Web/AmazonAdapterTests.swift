//
//  AmazonAdapterTests.swift
//  SingularityTests
//

import Foundation
import Testing

@testable import Singularity

struct AmazonAdapterTests {
    /// T-P5-20: declares Amazon hosts and an isolated data store.
    @Test func declaresHostsAndOwnStore() {
        let adapter = AmazonAdapter()
        #expect(adapter.allowedHosts.contains("www.amazon.com"))
        #expect(adapter.dataStoreIdentifier != YouTubeAdapter().dataStoreIdentifier)
    }

    /// Placing the order is `.spend` risk (Touch ID + confirm).
    @Test func placingOrderIsSpendRisk() {
        #expect(AmazonAdapter.placeOrderRisk == .spend)
    }

    /// Two distinct confirm stops carry the item / total.
    @Test func twoStopPreviewsCarryDetails() {
        #expect(AmazonAdapter.addToCartPreview(item: "Sony XM5").detail.contains("Sony XM5"))
        let order = AmazonAdapter.placeOrderPreview(item: "Sony XM5", total: "$349.99")
        #expect(order.detail.contains("$349.99"))
    }
}
