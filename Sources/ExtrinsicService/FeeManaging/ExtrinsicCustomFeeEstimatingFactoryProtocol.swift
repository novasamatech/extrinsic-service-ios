import Foundation
import SubstrateSdk

protocol ExtrinsicCustomFeeEstimatingFactoryProtocol {
    func createCustomFeeEstimator(for chainAsset: ChainAssetProtocol) -> ExtrinsicFeeEstimating?
}
