import Foundation
import Operation_iOS
import SubstrateSdk

protocol ExtrinsicFeeInstallingFactoryProtocol {
    func createFeeInstallerWrapper(
        chainAsset: ChainAssetProtocol,
        accountClosure: @escaping () throws -> AccountProtocol
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling>
}
