import Foundation
import Operation_iOS
import SubstrateSdk
import CommonMissing

enum ExtrinsicFeeEstimationRegistryError: Error {
    case unexpectedAsset(AssetProtocol)
    case unexpectedChainAssetId(ChainAssetIdProtocol?)
}

final class ExtrinsicFeeEstimationRegistry {
    let chain: ChainProtocol
    let estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactoryProtocol
    let feeInstallingWrapperFactory: ExtrinsicFeeInstallingFactoryProtocol

    init(
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
    func createFeeEstimatingWrapper(
        payingIn chainAssetId: ChainAssetIdProtocol?,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        guard let chainAssetId else {
            return estimatingWrapperFactory.createNativeFeeEstimatingWrapper(
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        }

        guard
            chain.chainId == chainAssetId.chainId,
            let asset = chain.asset(for: chainAssetId.assetId)
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

    func createFeeInstallerWrapper(
        payingIn chainAssetId: ChainAssetIdProtocol?,
        accountClosure: @escaping () throws -> AccountProtocol
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        let targetAssetId = chainAssetId ?? chain.utilityChainAssetId()

        guard
            let targetAssetId,
            targetAssetId.chainId == chain.chainId,
            let asset = chain.chainAsset(for: targetAssetId.assetId)
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
