import Foundation
import Operation_iOS
import CommonMissing

protocol ExtrinsicCustomFeeEstimatingFactoryProtocol {
    func createCustomFeeEstimator(for chainAsset: ChainAsset) -> ExtrinsicFeeEstimating?
}
