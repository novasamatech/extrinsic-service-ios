import Foundation
@testable import ExtrinsicService

final class ExtrinsicSubmittingMock: ExtrinsicSubmitting {
    struct SubscribeCall {
        let builtExtrinsic: ExtrinsicBuiltModel
        let queue: DispatchQueue
        let subscriptionIdClosure: ExtrinsicSubscriptionIdClosure
        let notificationClosure: ExtrinsicSubscriptionStatusClosure
    }

    let submitted = AsyncExpectation()
    let subscribed = AsyncExpectation()
    let cancelled = AsyncExpectation()

    var submitHandler: (([ExtrinsicBuiltModel]) -> [SubmitExtrinsicResult])?

    private let lock = NSLock()
    private var storedSubmitCalls: [[ExtrinsicBuiltModel]] = []
    private var storedSubscribeCalls: [SubscribeCall] = []
    private var storedCancelledIds: [UInt16] = []

    var submitCalls: [[ExtrinsicBuiltModel]] {
        lock.withLock { storedSubmitCalls }
    }

    var subscribeCalls: [SubscribeCall] {
        lock.withLock { storedSubscribeCalls }
    }

    var cancelledIds: [UInt16] {
        lock.withLock { storedCancelledIds }
    }

    func submit(
        builtExtrinsics: [ExtrinsicBuiltModel],
        completion: @escaping ExtrinsicSubmitResultsClosure
    ) {
        let handler: (([ExtrinsicBuiltModel]) -> [SubmitExtrinsicResult])? = lock.withLock {
            storedSubmitCalls.append(builtExtrinsics)
            return submitHandler
        }

        let results = handler?(builtExtrinsics) ?? builtExtrinsics.map { builtExtrinsic in
            .success(ExtrinsicSubmittedModel(txHash: builtExtrinsic.extrinsic, sender: builtExtrinsic.sender))
        }

        submitted.fulfill()

        completion(results)
    }

    func submitAndSubscribe(
        builtExtrinsic: ExtrinsicBuiltModel,
        runningIn queue: DispatchQueue,
        subscriptionIdClosure: @escaping ExtrinsicSubscriptionIdClosure,
        notificationClosure: @escaping ExtrinsicSubscriptionStatusClosure
    ) {
        let call = SubscribeCall(
            builtExtrinsic: builtExtrinsic,
            queue: queue,
            subscriptionIdClosure: subscriptionIdClosure,
            notificationClosure: notificationClosure
        )

        lock.withLock { storedSubscribeCalls.append(call) }

        subscribed.fulfill()
    }

    func cancelExtrinsicWatch(for identifier: UInt16) {
        lock.withLock { storedCancelledIds.append(identifier) }

        cancelled.fulfill()
    }
}
