import Foundation
import SubstrateSdk
import Operation_iOS

public final class DefaultExtrinsicSubmitter {
    let operationFactory: ExtrinsicOperationFactoryProtocol
    let operationQueue: OperationQueue
    let timeout: Int

    public init(
        operationFactory: ExtrinsicOperationFactoryProtocol,
        operationQueue: OperationQueue,
        timeout: Int
    ) {
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
        self.timeout = timeout
    }
}

extension DefaultExtrinsicSubmitter: ExtrinsicSubmitting {
    public func submit(
        builtExtrinsics: [ExtrinsicBuiltModel],
        completion: @escaping ExtrinsicSubmitResultsClosure
    ) {
        let submitOperations: [JSONRPCListOperation<String>] = builtExtrinsics.map { builtExtrinsic in
            JSONRPCListOperation<String>(
                engine: operationFactory.connection,
                method: RPCMethod.submitExtrinsic,
                parameters: [builtExtrinsic.extrinsic],
                options: JSONRPCOptions(resendOnReconnect: false),
                timeout: timeout
            )
        }

        let resultOperation = ClosureOperation<[SubmitExtrinsicResult]> {
            zip(builtExtrinsics, submitOperations).map { builtExtrinsic, submitOperation in
                if let result = submitOperation.result {
                    return result.map { txHash in
                        ExtrinsicSubmittedModel(txHash: txHash, sender: builtExtrinsic.sender)
                    }
                } else {
                    return .failure(BaseOperationError.parentOperationCancelled)
                }
            }
        }

        submitOperations.forEach { resultOperation.addDependency($0) }

        resultOperation.completionBlock = {
            let results = (try? resultOperation.extractNoCancellableResultData())
                ?? builtExtrinsics.map { _ in .failure(BaseOperationError.parentOperationCancelled) }

            completion(results)
        }

        operationQueue.addOperations(submitOperations + [resultOperation], waitUntilFinished: false)
    }

    public func submitAndSubscribe(
        builtExtrinsic: ExtrinsicBuiltModel,
        runningIn queue: DispatchQueue,
        subscriptionIdClosure: @escaping ExtrinsicSubscriptionIdClosure,
        notificationClosure: @escaping ExtrinsicSubscriptionStatusClosure
    ) {
        do {
            let extrinsic = builtExtrinsic.extrinsic
            let extrinsicHash = try Data(hexString: extrinsic).blake2b32().toHex(includePrefix: true)

            let localModel = ExtrinsicSubscribedStatusModel(
                statusUpdate: ExtrinsicStatusUpdate(
                    extrinsicHash: extrinsicHash,
                    extrinsicStatus: .created
                ),
                sender: builtExtrinsic.sender
            )

            queue.async {
                notificationClosure(.success(localModel))
            }

            let updateClosure: (ExtrinsicSubscriptionUpdate) -> Void = { update in
                let status = update.params.result

                let model = ExtrinsicSubscribedStatusModel(
                    statusUpdate: ExtrinsicStatusUpdate(
                        extrinsicHash: extrinsicHash,
                        extrinsicStatus: .onChain(status)
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
                options: JSONRPCOptions(resendOnReconnect: false),
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
