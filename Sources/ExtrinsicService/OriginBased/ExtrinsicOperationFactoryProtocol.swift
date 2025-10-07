import Foundation
import Operation_iOS
import SubstrateSdk
import NovaCrypto
import BigInt
import CommonMissing

public protocol ExtrinsicOperationFactoryProtocol {
    var connection: JSONRPCEngine { get }
    
    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetIdProtocol?,
        indexes: IndexSet
    ) -> CompoundOperationWrapper<FeeIndexedExtrinsicResult>

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetIdProtocol?,
        indexes: IndexSet
    ) -> CompoundOperationWrapper<SubmitIndexedExtrinsicResult>

    func buildExtrinsic(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetIdProtocol?
    ) -> CompoundOperationWrapper<ExtrinsicBuiltModel>
}

public extension ExtrinsicOperationFactoryProtocol {
    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetIdProtocol?,
        numberOfExtrinsics: Int
    ) -> CompoundOperationWrapper<FeeIndexedExtrinsicResult> {
        estimateFeeOperation(
            closure,
            origin: origin,
            payingIn: chainAssetId,
            indexes: IndexSet(0 ..< numberOfExtrinsics)
        )
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetIdProtocol?,
        numberOfExtrinsics: Int
    ) -> CompoundOperationWrapper<SubmitIndexedExtrinsicResult> {
        submit(
            closure,
            origin: origin,
            payingIn: chainAssetId,
            indexes: IndexSet(0 ..< numberOfExtrinsics)
        )
    }
    
    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetIdProtocol?
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        let wrapperClosure: ExtrinsicBuilderIndexedClosure = { builder, _ in
            try closure(builder)
        }
        
        let feeOperation = estimateFeeOperation(
            wrapperClosure,
            origin: origin,
            payingIn: chainAssetId,
            numberOfExtrinsics: 1
        )

        let resultMappingOperation = ClosureOperation<ExtrinsicFeeProtocol> {
            guard let result = try feeOperation.targetOperation.extractNoCancellableResultData()
                .results.first?.result else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return try result.get()
        }

        resultMappingOperation.addDependency(feeOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultMappingOperation,
            dependencies: feeOperation.allOperations
        )
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetIdProtocol?,
    ) -> CompoundOperationWrapper<ExtrinsicSubmittedModel> {
        let wrapperClosure: ExtrinsicBuilderIndexedClosure = { builder, _ in
            try closure(builder)
        }

        let submitOperation = submit(
            wrapperClosure,
            origin: origin,
            payingIn: chainAssetId,
            numberOfExtrinsics: 1
        )

        let resultMappingOperation = ClosureOperation<ExtrinsicSubmittedModel> {
            guard let result = try submitOperation.targetOperation.extractNoCancellableResultData()
                .results.first?.result else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return try result.get()
        }

        resultMappingOperation.addDependency(submitOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultMappingOperation,
            dependencies: submitOperation.allOperations
        )
    }
}
