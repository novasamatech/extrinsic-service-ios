import Foundation
import SubstrateSdk
import Operation_iOS
import BigInt

enum BaseExtrinsicOperationFactoryError: Error {
    case undefinedCryptoType
    case brokenFee
    case missingExtrinsic
}

class BaseExtrinsicOperationFactory {
    let feeEstimationRegistry: ExtrinsicFeeEstimationRegistring
    let runtimeRegistry: RuntimeCodingServiceProtocol
    let engine: JSONRPCEngine
    let operationQueue: OperationQueue
    let timeout: Int

    init(
        feeEstimationRegistry: ExtrinsicFeeEstimationRegistring,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationQueue: OperationQueue,
        timeout: Int
    ) {
        self.feeEstimationRegistry = feeEstimationRegistry
        self.runtimeRegistry = runtimeRegistry
        self.engine = engine
        self.operationQueue = operationQueue
        self.timeout = timeout
    }

    func createExtrinsicWrapper(
        customClosure _: @escaping ExtrinsicBuilderIndexedClosure,
        origin _: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetIdProtocol?,
        purpose _: ExtrinsicOriginPurpose,
        indexes _: [Int]
    ) -> CompoundOperationWrapper<ExtrinsicsCreationResult> {
        fatalError("Subclass must override this method")
    }
}

extension BaseExtrinsicOperationFactory: ExtrinsicOperationFactoryProtocol {
    var connection: JSONRPCEngine { engine }

    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetIdProtocol?,
        indexes: IndexSet
    ) -> CompoundOperationWrapper<FeeIndexedExtrinsicResult> {
        let indexList = Array(indexes)

        let builderWrapper = createExtrinsicWrapper(
            customClosure: closure,
            origin: origin,
            payingIn: chainAssetId,
            purpose: .feeEstimation,
            indexes: indexList
        )

        let coderFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()

        let feeWrapper = feeEstimationRegistry.createFeeEstimatingWrapper(
            payingIn: chainAssetId,
            extrinsicCreatingResultClosure: {
                try builderWrapper.targetOperation.extractNoCancellableResultData()
            }
        )

        feeWrapper.addDependency(operations: [coderFactoryOperation])
        feeWrapper.addDependency(wrapper: builderWrapper)

        let wrapperOperation = ClosureOperation<ExtrinsicRetriableResult<ExtrinsicFeeProtocol>> {
            do {
                let result = try feeWrapper.targetOperation.extractNoCancellableResultData()

                let indexedResults = zip(indexList, result.items).map { indexedResult in
                    FeeIndexedExtrinsicResult.IndexedResult(
                        index: indexedResult.0,
                        result: .success(indexedResult.1)
                    )
                }

                return .init(builderClosure: closure, results: indexedResults)
            } catch {
                let indexedResults = indexList.map { index in
                    FeeIndexedExtrinsicResult.IndexedResult(index: index, result: .failure(error))
                }

                return .init(builderClosure: closure, results: indexedResults)
            }
        }

        wrapperOperation.addDependency(feeWrapper.targetOperation)

        return feeWrapper
            .insertingHead(operations: builderWrapper.allOperations + [coderFactoryOperation])
            .insertingTail(operation: wrapperOperation)
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetIdProtocol?,
        indexes: IndexSet
    ) -> CompoundOperationWrapper<SubmitIndexedExtrinsicResult> {
        let indexList = Array(indexes)

        let builderWrapper = createExtrinsicWrapper(
            customClosure: closure,
            origin: origin,
            payingIn: chainAssetId,
            purpose: .submission,
            indexes: indexList
        )

        let submitOperationList: [JSONRPCListOperation<String>] =
            indexList.map { index in
                let submitOperation = JSONRPCListOperation<String>(
                    engine: engine,
                    method: RPCMethod.submitExtrinsic,
                    timeout: timeout
                )

                submitOperation.configurationBlock = {
                    do {
                        let extrinsics = try builderWrapper.targetOperation.extractNoCancellableResultData().extrinsics
                        let extrinsic = extrinsics[index].toHex(includePrefix: true)

                        submitOperation.parameters = [extrinsic]
                    } catch {
                        submitOperation.result = .failure(error)
                    }
                }

                submitOperation.addDependency(builderWrapper.targetOperation)

                return submitOperation
            }

        let wrapperOperation = ClosureOperation<SubmitIndexedExtrinsicResult> {
            do {
                let sender = try builderWrapper.targetOperation.extractNoCancellableResultData().sender

                let indexedResults = zip(indexList, submitOperationList).map { indexedOperation in

                    if let result = indexedOperation.1.result {
                        let mappedResult = result.map { txHash in
                            ExtrinsicSubmittedModel(txHash: txHash, sender: sender)
                        }
                        return SubmitIndexedExtrinsicResult.IndexedResult(
                            index: indexedOperation.0,
                            result: mappedResult
                        )
                    } else {
                        return SubmitIndexedExtrinsicResult.IndexedResult(
                            index: indexedOperation.0,
                            result: .failure(BaseOperationError.parentOperationCancelled)
                        )
                    }
                }

                return .init(builderClosure: closure, results: indexedResults)
            } catch {
                let indexedResults = indexList.map { index in
                    SubmitIndexedExtrinsicResult.IndexedResult(
                        index: index,
                        result: .failure(error)
                    )
                }

                return .init(builderClosure: closure, results: indexedResults)
            }
        }

        submitOperationList.forEach { submitOperation in
            wrapperOperation.addDependency(submitOperation)
        }

        return CompoundOperationWrapper(
            targetOperation: wrapperOperation,
            dependencies: builderWrapper.allOperations + submitOperationList
        )
    }

    func buildExtrinsic(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetIdProtocol?,
    ) -> CompoundOperationWrapper<ExtrinsicBuiltModel> {
        let wrapperClosure: ExtrinsicBuilderIndexedClosure = { builder, _ in
            try closure(builder)
        }

        let builderWrapper = createExtrinsicWrapper(
            customClosure: wrapperClosure,
            origin: origin,
            payingIn: chainAssetId,
            purpose: .submission,
            indexes: [0]
        )

        let resOperation: ClosureOperation<ExtrinsicBuiltModel> = ClosureOperation {
            let extrinsicsWithSender = try builderWrapper.targetOperation.extractNoCancellableResultData()

            guard let extrinsic = extrinsicsWithSender.extrinsics.first else {
                throw BaseExtrinsicOperationFactoryError.missingExtrinsic
            }
            
            let model = ExtrinsicBuiltModel(
                extrinsic: extrinsic.toHex(includePrefix: true),
                sender: extrinsicsWithSender.sender
            )
            
            return model
        }
        
        builderWrapper.allOperations.forEach {
            resOperation.addDependency($0)
        }

        return CompoundOperationWrapper(targetOperation: resOperation, dependencies: builderWrapper.allOperations)
    }
}
