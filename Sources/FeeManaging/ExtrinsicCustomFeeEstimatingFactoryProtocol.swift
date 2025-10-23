import Foundation
import SubstrateSdk

public protocol ExtrinsicCustomFeeEstimatingFactoryProtocol {
    func createCustomFeeEstimator(for chainAsset: ChainAssetProtocol) -> ExtrinsicFeeEstimating?
}
