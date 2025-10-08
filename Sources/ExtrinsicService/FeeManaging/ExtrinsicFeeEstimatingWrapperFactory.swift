import Operation_iOS
import SubstrateSdk

public protocol ExtrinsicFeeEstimatingWrapperFactoryProtocol {
    func createNativeFeeEstimatingWrapper(
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol>

    func createCustomFeeEstimatingWrapper(
        asset: AssetProtocol,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol>
}

public final class ExtrinsicFeeEstimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactoryProtocol {
    let host: ExtrinsicFeeEstimatorHostProtocol
    let customFeeEstimatorFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol

    init(
        host: ExtrinsicFeeEstimatorHostProtocol,
        customFeeEstimatorFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol
    ) {
        self.host = host
        self.customFeeEstimatorFactory = customFeeEstimatorFactory
    }

    public func createNativeFeeEstimatingWrapper(
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        ExtrinsicNativeFeeEstimator(
            chain: host.chain,
            operationQueue: host.operationQueue
        ).createFeeEstimatingWrapper(
            connection: host.connection,
            runtimeService: host.runtimeProvider,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )
    }

    public func createCustomFeeEstimatingWrapper(
        asset: AssetProtocol,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        guard
            let chainAsset = host.chain.chainAsset(for: asset.assetId),
            let customFeeEstimator = customFeeEstimatorFactory.createCustomFeeEstimator(
                for: chainAsset
            ) else {
            return .createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedAsset(asset)
            )
        }

        return customFeeEstimator.createFeeEstimatingWrapper(
            connection: host.connection,
            runtimeService: host.runtimeProvider,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )
    }
}
