import Foundation
import SubstrateSdk

public struct ExtrinsicSubmissionParams {
    public let feeAssetId: ChainAssetId?
    public let eventsMatcher: ExtrinsicEventsMatching?
    
    public init(feeAssetId: ChainAssetId?, eventsMatcher: ExtrinsicEventsMatching?) {
        self.feeAssetId = feeAssetId
        self.eventsMatcher = eventsMatcher
    }
}
