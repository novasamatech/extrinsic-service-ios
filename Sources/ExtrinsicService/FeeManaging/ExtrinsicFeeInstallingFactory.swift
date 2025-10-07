import Foundation
import Operation_iOS
import CommonMissing

protocol ExtrinsicFeeInstallingFactoryProtocol {
    func createFeeInstallerWrapper(
        chainAsset: ChainAssetProtocol,
        accountClosure: @escaping () throws -> AccountProtocol
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling>
}
