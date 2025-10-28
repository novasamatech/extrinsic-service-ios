import Foundation
import Operation_iOS
import SubstrateSdk

enum ExtrinsicFeeEstimationRegistryError: Error {
    case unexpectedAsset(AssetProtocol)
    case unexpectedChainAssetId(ChainAssetId?)
}

public final class ExtrinsicFeeEstimationRegistry {
    let chain: ChainProtocol
    let estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactoryProtocol
    let feeInstallingWrapperFactory: ExtrinsicFeeInstallingFactoryProtocol

    public init(
        chain: ChainProtocol,
        estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactoryProtocol,
        feeInstallingWrapperFactory: ExtrinsicFeeInstallingFactoryProtocol
    ) {
        self.chain = chain
        self.estimatingWrapperFactory = estimatingWrapperFactory
        self.feeInstallingWrapperFactory = feeInstallingWrapperFactory
    }
}

private extension ExtrinsicFeeEstimationRegistry {
    func createFeeEstimatingWrapper(
        for asset: AssetProtocol,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        guard !asset.isUtility else {
            return estimatingWrapperFactory.createNativeFeeEstimatingWrapper(
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        }

        return estimatingWrapperFactory.createCustomFeeEstimatingWrapper(
            asset: asset,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )
    }
}

extension ExtrinsicFeeEstimationRegistry: ExtrinsicFeeEstimationRegistring {
    public func createFeeEstimatingWrapper(
        payingIn chainAssetId: ChainAssetId?,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        guard let chainAssetId else {
            return estimatingWrapperFactory.createNativeFeeEstimatingWrapper(
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        }

        guard
            chain.chainId == chainAssetId.chainId,
            let asset = chain.assetInteface(for: chainAssetId.assetId)
        else {
            return CompoundOperationWrapper.createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAssetId)
            )
        }

        return createFeeEstimatingWrapper(
            for: asset,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )
    }

    public func createFeeInstallerWrapper(
        payingIn chainAssetId: ChainAssetId?,
        accountClosure: @escaping () throws -> AccountProtocol
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        let targetAssetId = chainAssetId ?? chain.utilityChainAssetId()

        guard
            let targetAssetId,
            targetAssetId.chainId == chain.chainId,
            let asset = chain.chainAssetInterface(for: targetAssetId.assetId)
        else {
            return .createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(targetAssetId)
            )
        }

        return feeInstallingWrapperFactory.createFeeInstallerWrapper(
            chainAsset: asset,
            accountClosure: accountClosure
        )
    }
}
