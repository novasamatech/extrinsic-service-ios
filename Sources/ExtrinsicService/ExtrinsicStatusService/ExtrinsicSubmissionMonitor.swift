import Foundation
import Operation_iOS
import CommonMissing

protocol ExtrinsicSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        params: ExtrinsicSubmissionParams
    ) -> CompoundOperationWrapper<SubstrateExtrinsicStatus>
}

final class ExtrinsicSubmissionMonitorFactory {
    struct SubmissionResult {
        let blockHash: String
        let extrinsicHash: String
    }

    let submissionService: ExtrinsicServiceProtocol
    let statusService: ExtrinsicStatusServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol
    let processingQueue = DispatchQueue(label: "io.extrinsic.service.monitor.\(UUID().uuidString)")

    init(
        submissionService: ExtrinsicServiceProtocol,
        statusService: ExtrinsicStatusServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.submissionService = submissionService
        self.statusService = statusService
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension ExtrinsicSubmissionMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol {
    func submitAndMonitorWrapper(
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        params: ExtrinsicSubmissionParams
    ) -> CompoundOperationWrapper<SubstrateExtrinsicStatus> {
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

        return statusWrapper.insertingHead(operations: [submissionOperation])
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
            let update = model.statusUpdate
            logger.debug("Extrinsic notification status update: \(update.extrinsicStatus)")

            guard let blockHash = update.getInBlockOrFinalizedHash() else {
                logger.warning("Extrinsic notification skipped")
                return
            }

            if let subscriptionId {
                submissionService.cancelExtrinsicWatch(for: subscriptionId)
            } else {
                logger.warning("Missing subscription id")
            }

            let response = SubmissionResult(
                blockHash: blockHash,
                extrinsicHash: update.extrinsicHash
            )

            completionClosure(.success(response))
        case let .failure(error):
            logger.error("Extrinsic notification error: \(error.localizedDescription)")

            if let subscriptionId {
                submissionService.cancelExtrinsicWatch(for: subscriptionId)
            } else {
                logger.warning("Missing subscription id")
            }

            completionClosure(.failure(error))
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
