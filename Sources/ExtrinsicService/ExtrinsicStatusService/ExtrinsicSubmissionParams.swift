import Foundation
import SubstrateSdk

public struct ExtrinsicSubmissionParams {
    let feeAssetId: ChainAssetIdProtocol?
    let eventsMatcher: ExtrinsicEventsMatching?
}
