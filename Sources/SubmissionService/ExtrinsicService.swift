import Foundation
import SubstrateSdk
import Operation_iOS
import NovaCrypto
import SubstrateMetadataHash

public final class ExtrinsicService {
    let operationFactory: ExtrinsicOperationFactoryProtocol
    let operationQueue: OperationQueue
    let submitter: ExtrinsicSubmitting

    public init(
        chain: ChainProtocol,
        extrinsicVersion: Extrinsic.Version,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        feeEstimationRegistry: ExtrinsicFeeEstimationRegistring,
        metadataHashOperationFactory: MetadataHashOperationFactoryProtocol,
        eraOperationFactory: ExtrinsicEraOperationFactoryProtocol,
        extensions: [TransactionExtending],
        engine: JSONRPCEngine,
        operationQueue: OperationQueue,
        timeout: Int,
        submitter: ExtrinsicSubmitting? = nil
    ) {
        let operationFactory = ExtrinsicOperationFactory(
            chain: chain,
            extrinsicVersion: extrinsicVersion,
            feeEstimationRegistry: feeEstimationRegistry,
            runtimeRegistry: runtimeRegistry,
            customExtensions: extensions,
            engine: engine,
            metadataHashOperationFactory: metadataHashOperationFactory,
            eraOperationFactory: eraOperationFactory,
            operationQueue: operationQueue,
            timeout: timeout
        )

        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
        self.submitter = submitter ?? DefaultExtrinsicSubmitter(
            operationFactory: operationFactory,
            operationQueue: operationQueue,
            timeout: timeout
        )
    }
}

extension ExtrinsicService: ExtrinsicServiceProtocol {
    public func estimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    ) {
        let wrapper = operationFactory.estimateFeeOperation(
            closure,
            origin: origin,
            payingIn: chainAssetId
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue,
            callbackClosure: completionClosure
        )
    }

    public func estimateFee(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        indexes: IndexSet,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        let wrapper = operationFactory.estimateFeeOperation(
            closure,
            origin: origin,
            payingIn: chainAssetId,
            indexes: indexes
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { result in
            switch result {
            case let .success(operationResult):
                completionClosure(operationResult)
            case let .failure(error):
                let result = FeeIndexedExtrinsicResult(
                    builderClosure: closure,
                    error: error,
                    indexes: Array(indexes)
                )

                completionClosure(result)
            }
        }
    }

    public func estimateFeeWithSplitter(
        _ splitter: ExtrinsicSplitting,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        let extrinsicsWrapper = splitter.buildWrapper(
            using: operationFactory,
            origin: origin
        )

        let feeWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let result = try extrinsicsWrapper.targetOperation.extractNoCancellableResultData()

            return self.operationFactory.estimateFeeOperation(
                result.closure,
                origin: origin,
                payingIn: chainAssetId,
                numberOfExtrinsics: result.numberOfExtrinsics
            )
        }

        feeWrapper.addDependency(wrapper: extrinsicsWrapper)

        let totalWrapper = feeWrapper.insertingHead(operations: extrinsicsWrapper.allOperations)

        execute(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { result in
            switch result {
            case let .success(operationResult):
                completionClosure(operationResult)
            case let .failure(error):
                let splitterResult = try? extrinsicsWrapper.targetOperation.extractNoCancellableResultData()
                let numberOfExtrinsics = splitterResult?.numberOfExtrinsics ?? 1
                let result = FeeIndexedExtrinsicResult(
                    builderClosure: splitterResult?.closure,
                    error: error,
                    indexes: Array(0 ..< numberOfExtrinsics)
                )

                completionClosure(result)
            }
        }
    }

    public func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        indexes: IndexSet,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        let wrapper = submitBuiltWrapper(
            closure,
            origin: origin,
            payingIn: chainAssetId,
            indexes: indexes
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { result in
            switch result {
            case let .success(operationResult):
                completionClosure(operationResult)
            case let .failure(error):
                let result = SubmitIndexedExtrinsicResult(
                    builderClosure: closure,
                    error: error,
                    indexes: Array(indexes)
                )

                completionClosure(result)
            }
        }
    }

    public func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    ) {
        let wrapper = submitBuiltWrapper(
            closure,
            origin: origin,
            payingIn: chainAssetId
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue,
            callbackClosure: completionClosure
        )
    }

    public func submitWithTxSplitter(
        _ txSplitter: ExtrinsicSplitting,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        let extrinsicsWrapper = txSplitter.buildWrapper(
            using: operationFactory,
            origin: origin
        )

        let submissionWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let result = try extrinsicsWrapper.targetOperation.extractNoCancellableResultData()

            return self.submitBuiltWrapper(
                result.closure,
                origin: origin,
                payingIn: chainAssetId,
                indexes: IndexSet(0 ..< result.numberOfExtrinsics)
            )
        }

        submissionWrapper.addDependency(wrapper: extrinsicsWrapper)

        let totalWrapper = submissionWrapper.insertingHead(operations: extrinsicsWrapper.allOperations)

        execute(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { result in
            switch result {
            case let .success(operationResult):
                completionClosure(operationResult)
            case let .failure(error):
                let splitterResult = try? extrinsicsWrapper.targetOperation.extractNoCancellableResultData()
                let numberOfExtrinsics = splitterResult?.numberOfExtrinsics ?? 1
                let result = SubmitIndexedExtrinsicResult(
                    builderClosure: splitterResult?.closure,
                    error: error,
                    indexes: Array(0 ..< numberOfExtrinsics)
                )

                completionClosure(result)
            }
        }
    }

    public func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        subscriptionIdClosure: @escaping ExtrinsicSubscriptionIdClosure,
        notificationClosure: @escaping ExtrinsicSubscriptionStatusClosure
    ) {
        let submitter = self.submitter
        let extrinsicWrapper = operationFactory.buildExtrinsic(
            closure,
            origin: origin,
            payingIn: chainAssetId
        )

        execute(
            wrapper: extrinsicWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { result in
            switch result {
            case let .success(extrinsic):
                submitter.submitAndSubscribe(
                    builtExtrinsic: extrinsic,
                    runningIn: queue,
                    subscriptionIdClosure: subscriptionIdClosure,
                    notificationClosure: notificationClosure
                )
            case let .failure(error):
                notificationClosure(.failure(error))
            }
        }
    }

    public func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        indexes: IndexSet,
        subscriptionIdClosure: @escaping ExtrinsicSubscriptionIndexedIdClosure,
        notificationClosure: @escaping ExtrinsicSubscriptionIndexedStatusClosure
    ) {
        let submitter = self.submitter
        let extrinsicsWrapper = operationFactory.buildExtrinsics(
            closure,
            origin: origin,
            payingIn: chainAssetId,
            indexes: indexes
        )

        execute(
            wrapper: extrinsicsWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { result in
            switch result {
            case let .success(builtExtrinsics):
                zip(Array(indexes), builtExtrinsics).forEach { index, builtExtrinsic in
                    submitter.submitAndSubscribe(
                        builtExtrinsic: builtExtrinsic,
                        runningIn: queue,
                        subscriptionIdClosure: { subscriptionId in
                            subscriptionIdClosure(index, subscriptionId)
                        },
                        notificationClosure: { statusResult in
                            notificationClosure(index, statusResult)
                        }
                    )
                }
            case let .failure(error):
                Array(indexes).forEach { index in
                    notificationClosure(index, .failure(error))
                }
            }
        }
    }

    public func cancelExtrinsicWatch(for identifier: UInt16) {
        submitter.cancelExtrinsicWatch(for: identifier)
    }

    public func buildExtrinsic(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicBuiltClosure
    ) {
        let extrinsicWrapper = operationFactory.buildExtrinsic(
            closure,
            origin: origin,
            payingIn: chainAssetId
        )

        execute(
            wrapper: extrinsicWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue,
            callbackClosure: completionClosure
        )
    }
}

private extension ExtrinsicService {
    func submitBuiltWrapper(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        indexes: IndexSet
    ) -> CompoundOperationWrapper<SubmitIndexedExtrinsicResult> {
        let indexList = Array(indexes)
        let submitter = self.submitter

        let buildWrapper = operationFactory.buildExtrinsics(
            closure,
            origin: origin,
            payingIn: chainAssetId,
            indexes: indexes
        )

        let submitOperation = AsyncClosureOperation<[SubmitExtrinsicResult]> { responseClosure in
            let builtExtrinsics = try buildWrapper.targetOperation.extractNoCancellableResultData()

            submitter.submit(builtExtrinsics: builtExtrinsics) { submitResults in
                responseClosure(.success(submitResults))
            }
        }

        submitOperation.addDependency(buildWrapper.targetOperation)

        let mapOperation = ClosureOperation<SubmitIndexedExtrinsicResult> {
            let submitResults = try submitOperation.extractNoCancellableResultData()

            let indexedResults = zip(indexList, submitResults).map { index, submitResult in
                SubmitIndexedExtrinsicResult.IndexedResult(index: index, result: submitResult)
            }

            return SubmitIndexedExtrinsicResult(builderClosure: closure, results: indexedResults)
        }

        mapOperation.addDependency(submitOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: buildWrapper.allOperations + [submitOperation]
        )
    }

    func submitBuiltWrapper(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?
    ) -> CompoundOperationWrapper<ExtrinsicSubmittedModel> {
        let submitter = self.submitter

        let buildWrapper = operationFactory.buildExtrinsic(
            closure,
            origin: origin,
            payingIn: chainAssetId
        )

        let submitOperation = AsyncClosureOperation<ExtrinsicSubmittedModel> { responseClosure in
            let builtExtrinsic = try buildWrapper.targetOperation.extractNoCancellableResultData()

            submitter.submit(builtExtrinsics: [builtExtrinsic]) { submitResults in
                guard let submitResult = submitResults.first else {
                    responseClosure(.failure(BaseOperationError.unexpectedDependentResult))
                    return
                }

                responseClosure(submitResult)
            }
        }

        submitOperation.addDependency(buildWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: submitOperation,
            dependencies: buildWrapper.allOperations
        )
    }
}
