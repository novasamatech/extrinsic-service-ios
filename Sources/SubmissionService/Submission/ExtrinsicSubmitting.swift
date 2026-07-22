import Foundation

public typealias ExtrinsicSubmitResultsClosure = ([SubmitExtrinsicResult]) -> Void

public protocol ExtrinsicSubmitting {
    func submit(
        builtExtrinsics: [ExtrinsicBuiltModel],
        completion: @escaping ExtrinsicSubmitResultsClosure
    )

    func submitAndSubscribe(
        builtExtrinsic: ExtrinsicBuiltModel,
        runningIn queue: DispatchQueue,
        subscriptionIdClosure: @escaping ExtrinsicSubscriptionIdClosure,
        notificationClosure: @escaping ExtrinsicSubscriptionStatusClosure
    )

    func cancelExtrinsicWatch(for identifier: UInt16)
}
