import Foundation
import CommonMissing

struct ExtrinsicSubmissionParams {
    let feeAssetId: ChainAssetIdProtocol?
    let eventsMatcher: ExtrinsicEventsMatching?
}
