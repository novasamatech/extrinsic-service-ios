import Foundation
import SubstrateSdk
import Operation_iOS
import NovaCrypto
import CommonMissing

protocol ExtrinsicServiceProtocol {
    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    )

    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        indexes: IndexSet,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    )

    func estimateFeeWithSplitter(
        _ splitter: ExtrinsicSplitting,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    )

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    )

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        indexes: IndexSet,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    )

    func submitWithTxSplitter(
        _ splitter: ExtrinsicSplitting,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    )

    func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        subscriptionIdClosure: @escaping ExtrinsicSubscriptionIdClosure,
        notificationClosure: @escaping ExtrinsicSubscriptionStatusClosure
    )

    func cancelExtrinsicWatch(for identifier: UInt16)

    func buildExtrinsic(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicBuiltClosure
    )
}

extension ExtrinsicServiceProtocol {
    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    ) {
        estimateFee(
            closure,
            origin: origin,
            payingIn: nil,
            runningIn: queue,
            completion: completionClosure
        )
    }
    
    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        runningIn queue: DispatchQueue,
        indexes: IndexSet,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        estimateFee(
            closure,
            origin: origin,
            payingIn: nil,
            runningIn: queue,
            indexes: indexes,
            completion: completionClosure
        )
    }
    
    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        estimateFee(
            closure,
            origin: origin,
            payingIn: nil,
            runningIn: queue,
            indexes: IndexSet(0 ..< numberOfExtrinsics),
            completion: completionClosure
        )
    }
    
    func estimateFeeWithSplitter(
        _ splitter: ExtrinsicSplitting,
        origin: ExtrinsicOriginDefining,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        estimateFeeWithSplitter(
            splitter,
            origin: origin,
            payingIn: nil,
            runningIn: queue,
            completion: completionClosure
        )
    }
    
    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    ) {
        submit(
            closure,
            origin: origin,
            payingIn: nil,
            runningIn: queue,
            completion: completionClosure
        )
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        submit(
            closure,
            origin: origin,
            payingIn: nil,
            runningIn: queue,
            indexes: IndexSet(0 ..< numberOfExtrinsics),
            completion: completionClosure
        )
    }
    
    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        runningIn queue: DispatchQueue,
        indexes: IndexSet,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        submit(
            closure,
            origin: origin,
            payingIn: nil,
            runningIn: queue,
            indexes: indexes,
            completion: completionClosure
        )
    }
    
    func submitWithTxSplitter(
        _ splitter: ExtrinsicSplitting,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        submitWithTxSplitter(
            splitter,
            origin: origin,
            payingIn: nil,
            runningIn: queue,
            completion: completionClosure
        )
    }

    func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        runningIn queue: DispatchQueue,
        subscriptionIdClosure: @escaping ExtrinsicSubscriptionIdClosure,
        notificationClosure: @escaping ExtrinsicSubscriptionStatusClosure
    ) {
        submitAndWatch(
            closure,
            origin: origin,
            payingIn: nil,
            runningIn: queue,
            subscriptionIdClosure: subscriptionIdClosure,
            notificationClosure: notificationClosure
        )
    }

    func buildExtrinsic(
        _ closure: @escaping ExtrinsicBuilderClosure,
        origin: ExtrinsicOriginDefining,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicBuiltClosure
    ) {
        buildExtrinsic(
            closure,
            origin: origin,
            payingIn: nil,
            runningIn: queue,
            completion: completionClosure
        )
    }
}
