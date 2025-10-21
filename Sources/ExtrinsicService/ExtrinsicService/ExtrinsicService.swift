import Foundation
import SubstrateSdk
import Operation_iOS
import NovaCrypto
import SubstrateMetadataHash

public final class ExtrinsicService {
    let operationFactory: ExtrinsicOperationFactoryProtocol
    let operationQueue: OperationQueue

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
        timeout: Int
    ) {
        operationFactory = ExtrinsicOperationFactory(
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

        self.operationQueue = operationQueue
    }

    private func submitAndSubscribe(
        builtExtrinsic: ExtrinsicBuiltModel,
        runningIn queue: DispatchQueue,
        subscriptionIdClosure: @escaping ExtrinsicSubscriptionIdClosure,
        notificationClosure: @escaping ExtrinsicSubscriptionStatusClosure
    ) {
        do {
            let extrinsic = builtExtrinsic.extrinsic
            let extrinsicHash = try Data(hexString: extrinsic).blake2b32().toHex(includePrefix: true)
            let updateClosure: (ExtrinsicSubscriptionUpdate) -> Void = { update in
                let status = update.params.result

                let model = ExtrinsicSubscribedStatusModel(
                    statusUpdate: ExtrinsicStatusUpdate(
                        extrinsicHash: extrinsicHash,
                        extrinsicStatus: status
                    ),
                    sender: builtExtrinsic.sender
                )

                queue.async {
                    notificationClosure(.success(model))
                }
            }

            let failureClosure: (Error, Bool) -> Void = { error, _ in
                queue.async {
                    notificationClosure(.failure(error))
                }
            }

            let subscriptionId = try operationFactory.connection.subscribe(
                RPCMethod.submitAndWatchExtrinsic,
                params: [extrinsic],
                unsubscribeMethod: "author_unwatchExtrinsic",
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )

            if !subscriptionIdClosure(subscriptionId) {
                // extrinsic still should be submitted but without subscription
                operationFactory.connection.cancelForIdentifier(subscriptionId)
            }
        } catch {
            notificationClosure(.failure(error))
        }
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
        let wrapper = operationFactory.estimateFeeOperation(closure, origin: origin, payingIn: chainAssetId)

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
        let extrinsicsWrapper = splitter.buildWrapper(using: operationFactory, origin: origin)

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
        let wrapper = operationFactory.submit(closure, origin: origin, payingIn: chainAssetId, indexes: indexes)

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
        let wrapper = operationFactory.submit(closure, origin: origin, payingIn: chainAssetId)

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
        let extrinsicsWrapper = txSplitter.buildWrapper(using: operationFactory, origin: origin)

        let submissionWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let result = try extrinsicsWrapper.targetOperation.extractNoCancellableResultData()

            return self.operationFactory.submit(
                result.closure,
                origin: origin,
                payingIn: chainAssetId,
                numberOfExtrinsics: result.numberOfExtrinsics
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
        let extrinsicWrapper = operationFactory.buildExtrinsic(closure, origin: origin, payingIn: chainAssetId)

        execute(
            wrapper: extrinsicWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue
        ) { [weak self] result in
            switch result {
            case let .success(extrinsic):
                self?.submitAndSubscribe(
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

    public func cancelExtrinsicWatch(for identifier: UInt16) {
        operationFactory.connection.cancelForIdentifier(identifier)
    }

    public func buildExtrinsic(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicBuiltClosure
    ) {
        let extrinsicWrapper = operationFactory.buildExtrinsic(closure, origin: origin, payingIn: chainAssetId)

        execute(
            wrapper: extrinsicWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue,
            callbackClosure: completionClosure
        )
    }
}
