import Foundation
import Operation_iOS
import SubstrateSdk
import SDKLogger

public protocol ExtrinsicSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        params: ExtrinsicSubmissionParams
    ) -> CompoundOperationWrapper<ExtrinsicMonitorSubmission>
}

public final class ExtrinsicSubmissionMonitorFactory {
    struct SubmissionResult {
        let blockHash: String
        let extrinsicHash: String
        let sender: ExtrinsicSenderResolution
    }

    let submissionService: ExtrinsicServiceProtocol
    let statusService: ExtrinsicStatusServiceProtocol
    let operationQueue: OperationQueue
    let logger: SDKLoggerProtocol
    let processingQueue = DispatchQueue(label: "io.extrinsic.service.monitor.\(UUID().uuidString)")

    public init(
        submissionService: ExtrinsicServiceProtocol,
        statusService: ExtrinsicStatusServiceProtocol,
        operationQueue: OperationQueue,
        logger: SDKLoggerProtocol
    ) {
        self.submissionService = submissionService
        self.statusService = statusService
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension ExtrinsicSubmissionMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol {
    public func submitAndMonitorWrapper(
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        params: ExtrinsicSubmissionParams
    ) -> CompoundOperationWrapper<ExtrinsicMonitorSubmission> {
        var subscriptionId: UInt16?

        let submissionOperation = AsyncClosureOperation<SubmissionResult>(operationClosure: { completionClosure in
            self.submissionService.submitAndWatch(
                extrinsicBuilderClosure,
                origin: origin,
                payingIn: params.feeAssetId,
                runningIn: self.processingQueue,
                subscriptionIdClosure: { identifier in
                    subscriptionId = identifier
                    return true
                },
                notificationClosure: { result in
                    self.handleNotification(
                        with: result,
                        subscriptionId: subscriptionId,
                        completionClosure: completionClosure
                    )
                }
            )
        }, cancelationClosure: {
            self.handleCancellation(forSubscriptionId: subscriptionId)
        })

        let statusWrapper: CompoundOperationWrapper<SubstrateExtrinsicStatus>
        statusWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let response = try submissionOperation.extractNoCancellableResultData()

            return self.statusService.fetchExtrinsicStatusForHash(
                response.extrinsicHash,
                inBlock: response.blockHash,
                matchingEvents: params.eventsMatcher
            )
        }

        statusWrapper.addDependency(operations: [submissionOperation])
        
        let mappingOperation = ClosureOperation<ExtrinsicMonitorSubmission> {
            let status = try statusWrapper.targetOperation.extractNoCancellableResultData()
            let submission = try submissionOperation.extractNoCancellableResultData()

            return ExtrinsicMonitorSubmission(
                extrinsicSubmittedModel: ExtrinsicSubmittedModel(
                    txHash: submission.extrinsicHash,
                    sender: submission.sender
                ),
                status: status
            )
        }

        mappingOperation.addDependency(statusWrapper.targetOperation)

        return statusWrapper
            .insertingHead(operations: [submissionOperation])
            .insertingTail(operation: mappingOperation)
    }
}

private extension ExtrinsicSubmissionMonitorFactory {
    func handleNotification(
        with result: Result<ExtrinsicSubscribedStatusModel, Error>,
        subscriptionId: UInt16?,
        completionClosure: (Result<SubmissionResult, Error>) -> Void
    ) {
        switch result {
        case let .success(model):
            logger.debug("Extrinsic notification status update: \(model.statusUpdate)")

            if handleInBlockOrFinalized(
                from: model,
                subscriptionId: subscriptionId,
                completionClosure: completionClosure
            ) {
                return
            }
            
            if handleFinalFailureStatus(
                from: model,
                subscriptionId: subscriptionId,
                completionClosure: completionClosure
            ) {
                return
            }
            
            logger.debug("Skiping extrinsic status")
            
        case let .failure(error):
            logger.error("Extrinsic notification error: \(error)")

            stopSubscription(for: subscriptionId)

            completionClosure(.failure(error))
        }
    }
    
    func handleInBlockOrFinalized(
        from model: ExtrinsicSubscribedStatusModel,
        subscriptionId: UInt16?,
        completionClosure: (Result<SubmissionResult, Error>) -> Void
    ) -> Bool {
        guard let blockHash = model.statusUpdate.getInBlockOrFinalizedHash() else {
            return false
        }

        stopSubscription(for: subscriptionId)

        let response = SubmissionResult(
            blockHash: blockHash,
            extrinsicHash: model.statusUpdate.extrinsicHash,
            sender: model.sender
        )

        completionClosure(.success(response))
        
        return true
    }
    
    func handleFinalFailureStatus(
        from model: ExtrinsicSubscribedStatusModel,
        subscriptionId: UInt16?,
        completionClosure: (Result<SubmissionResult, Error>) -> Void
    ) -> Bool {
        guard let failure = model.statusUpdate.getFinalExtrinsicFailure() else {
            return false
        }
        
        stopSubscription(for: subscriptionId)
        
        completionClosure(.failure(failure))
        
        return true
    }
    
    func stopSubscription(for subscriptionId: UInt16?) {
        if let subscriptionId {
            submissionService.cancelExtrinsicWatch(for: subscriptionId)
        } else {
            logger.warning("Missing subscription id")
        }
    }

    func handleCancellation(forSubscriptionId subscriptionId: UInt16?) {
        processingQueue.async {
            guard let subscriptionId else {
                return
            }
            self.submissionService.cancelExtrinsicWatch(for: subscriptionId)
        }
    }
}
