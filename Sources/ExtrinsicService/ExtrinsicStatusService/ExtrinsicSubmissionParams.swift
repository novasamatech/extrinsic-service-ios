import Foundation
import SubstrateSdk

struct ExtrinsicSubmissionParams {
    let feeAssetId: ChainAssetIdProtocol?
    let eventsMatcher: ExtrinsicEventsMatching?
}
