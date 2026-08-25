import Testing
import Foundation
@testable import ExtrinsicService

@Suite("ExtrinsicSubmissionParams defaults")
struct ExtrinsicSubmissionParamsTests {
    @Test func trackingTillDefaultsToInBlock() {
        let params = ExtrinsicSubmissionParams(feeAssetId: nil, eventsMatcher: nil)

        #expect(params.trackingTill == .inBlock)
    }

    @Test func indexedTrackingTillDefaultsToInBlock() {
        let params = ExtrinsicIndexedSubmissionParams(feeAssetId: nil, eventsMatcher: nil)

        #expect(params.trackingTill == .inBlock)
    }

    @Test func trackingTillIsConfigurable() {
        let params = ExtrinsicSubmissionParams(feeAssetId: nil, eventsMatcher: nil, trackingTill: .finalized)

        #expect(params.trackingTill == .finalized)
    }
}
