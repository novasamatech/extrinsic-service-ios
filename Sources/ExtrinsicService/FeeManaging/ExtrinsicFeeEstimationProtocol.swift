import Foundation
import Operation_iOS
import BigInt
import SubstrateSdk

public protocol ExtrinsicFeeEstimationResultProtocol {
    var items: [ExtrinsicFeeProtocol] { get }
}

enum ExtrinsicFeeEstimatingError: Error {
    case brokenFee
}

protocol ExtrinsicFeeEstimating {
    func createFeeEstimatingWrapper(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol>
}

protocol ExtrinsicFeeEstimationRegistring {
    func createFeeEstimatingWrapper(
        payingIn chainAssetId: ChainAssetIdProtocol?,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol>

    func createFeeInstallerWrapper(
        payingIn chainAssetId: ChainAssetIdProtocol?,
        accountClosure: @escaping () throws -> AccountProtocol
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling>
}
