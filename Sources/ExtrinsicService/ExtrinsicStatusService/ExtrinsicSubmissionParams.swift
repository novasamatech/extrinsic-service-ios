import Foundation
import SubstrateSdk

public struct ExtrinsicSubmissionParams {
    public let feeAssetId: ChainAssetIdProtocol?
    public let eventsMatcher: ExtrinsicEventsMatching?
    
    public init(feeAssetId: ChainAssetIdProtocol?, eventsMatcher: ExtrinsicEventsMatching?) {
        self.feeAssetId = feeAssetId
        self.eventsMatcher = eventsMatcher
    }
}
