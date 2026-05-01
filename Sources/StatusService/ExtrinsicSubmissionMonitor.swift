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

    func submitAndMonitorWrapper(
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        indexes: IndexSet,
        params: ExtrinsicIndexedSubmissionParams
    ) -> CompoundOperationWrapper<ExtrinsicRetriableResult<ExtrinsicMonitorSubmission>>
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
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        indexes: IndexSet,
        params: ExtrinsicIndexedSubmissionParams
    ) -> CompoundOperationWrapper<ExtrinsicRetriableResult<ExtrinsicMonitorSubmission>> {
        guard !indexes.isEmpty else {
            return .createWithResult(
                ExtrinsicRetriableResult(builderClosure: extrinsicBuilderClosure, results: [])
            )
        }

        let indexList = Array(indexes)
        let state = IndexedSubmissionState(indexList: indexList)

        let submissionOperation = AsyncClosureOperation<[IndexedSubmissionState.Submission]>(operationClosure: { completionClosure in
            self.submissionService.submitAndWatch(
                extrinsicBuilderClosure,
                origin: origin,
                payingIn: params.feeAssetId,
                runningIn: self.processingQueue,
                indexes: indexes,
                subscriptionIdClosure: { index, subscriptionId in
                    state.register(subscriptionId: subscriptionId, for: index)
                    return true
                },
                notificationClosure: { index, result in
                    params.statusNotificationClosure?(index, result.map { $0.statusUpdate })

                    guard state.handle(result, for: index) else {
                        self.logger.debug("Skipping extrinsic[\(index)] status")
                        return
                    }

                    self.stopSubscription(for: state.subscriptionId(for: index))

                    if let results = state.orderedResults() {
                        completionClosure(.success(results))
                    }
                }
            )
        }, cancelationClosure: {
            self.processingQueue.async {
                state.allSubscriptionIds().forEach { self.submissionService.cancelExtrinsicWatch(for: $0) }
            }
        })

        let monitorWrapper: CompoundOperationWrapper<ExtrinsicRetriableResult<ExtrinsicMonitorSubmission>>
        monitorWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let submissionResults = try submissionOperation.extractNoCancellableResultData()
            return self.createAggregateMonitorWrapper(
                indexList: indexList,
                submissionResults: submissionResults,
                params: params
            )
        }

        monitorWrapper.addDependency(operations: [submissionOperation])

        return monitorWrapper.insertingHead(operations: [submissionOperation])
    }

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
                        params: params,
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
        params: ExtrinsicSubmissionParams,
        completionClosure: (Result<SubmissionResult, Error>) -> Void
    ) {
        params.statusNotificationClosure?(result.map { $0.statusUpdate })

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

    func createAggregateMonitorWrapper(
        indexList: [Int],
        submissionResults: [Result<SubmissionResult, Error>],
        params: ExtrinsicIndexedSubmissionParams
    ) -> CompoundOperationWrapper<ExtrinsicRetriableResult<ExtrinsicMonitorSubmission>> {
        var statusItems: [(index: Int, submission: SubmissionResult, wrapper: CompoundOperationWrapper<SubstrateExtrinsicStatus>)] = []
        var failedItems: [(index: Int, error: Error)] = []

        for (index, result) in zip(indexList, submissionResults) {
            switch result {
            case let .success(submission):
                let wrapper = statusService.fetchExtrinsicStatusForHash(
                    submission.extrinsicHash,
                    inBlock: submission.blockHash,
                    matchingEvents: params.eventsMatcher
                )
                statusItems.append((index: index, submission: submission, wrapper: wrapper))
            case let .failure(error):
                failedItems.append((index: index, error: error))
            }
        }

        let aggregationOperation = ClosureOperation<ExtrinsicRetriableResult<ExtrinsicMonitorSubmission>> {
            var indexedResults: [ExtrinsicRetriableResult<ExtrinsicMonitorSubmission>.IndexedResult] = []

            for item in statusItems {
                do {
                    let status = try item.wrapper.targetOperation.extractNoCancellableResultData()
                    let monitor = ExtrinsicMonitorSubmission(
                        extrinsicSubmittedModel: ExtrinsicSubmittedModel(
                            txHash: item.submission.extrinsicHash,
                            sender: item.submission.sender
                        ),
                        status: status
                    )
                    indexedResults.append(.init(index: item.index, result: .success(monitor)))
                } catch {
                    indexedResults.append(.init(index: item.index, result: .failure(error)))
                }
            }

            for item in failedItems {
                indexedResults.append(.init(index: item.index, result: .failure(item.error)))
            }

            return ExtrinsicRetriableResult(
                builderClosure: nil,
                results: indexedResults.sorted { $0.index < $1.index }
            )
        }

        statusItems.forEach { aggregationOperation.addDependency($0.wrapper.targetOperation) }

        return CompoundOperationWrapper(
            targetOperation: aggregationOperation,
            dependencies: statusItems.flatMap { $0.wrapper.allOperations }
        )
    }
}

extension ExtrinsicSubmissionMonitorFactory {
    private final class IndexedSubmissionState {
        typealias Submission = Result<SubmissionResult, Error>

        private let indexList: [Int]
        private var subscriptionIds: [Int: UInt16] = [:]
        private var collectedResults: [Int: Submission] = [:]

        init(indexList: [Int]) { self.indexList = indexList }

        func register(subscriptionId: UInt16, for index: Int) {
            subscriptionIds[index] = subscriptionId
        }

        func subscriptionId(for index: Int) -> UInt16? {
            subscriptionIds[index]
        }

        func allSubscriptionIds() -> [UInt16] {
            Array(subscriptionIds.values)
        }

        // Returns true if this notification is terminal for the given index.
        // Idempotent: duplicate calls for same index return false.
        func handle(_ result: Result<ExtrinsicSubscribedStatusModel, Error>, for index: Int) -> Bool {
            guard collectedResults[index] == nil else { return false }

            switch result {
            case let .success(model):
                if let blockHash = model.statusUpdate.getInBlockOrFinalizedHash() {
                    collectedResults[index] = .success(SubmissionResult(
                        blockHash: blockHash,
                        extrinsicHash: model.statusUpdate.extrinsicHash,
                        sender: model.sender
                    ))
                } else if let failure = model.statusUpdate.getFinalExtrinsicFailure() {
                    collectedResults[index] = .failure(failure)
                } else {
                    return false
                }
            case let .failure(error):
                collectedResults[index] = .failure(error)
            }

            return true
        }

        // Returns ordered results once all indexes have a terminal result, nil otherwise.
        func orderedResults() -> [Submission]? {
            guard collectedResults.count == indexList.count else { return nil }
            return indexList.map { collectedResults[$0]! }
        }
    }
}
