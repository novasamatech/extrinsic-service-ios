import Foundation
import SubstrateSdk

public struct ExtrinsicSubmissionParams {
    public let feeAssetId: ChainAssetId?
    public let eventsMatcher: ExtrinsicEventsMatching?
    public let statusNotificationClosure: ExtrinsicStatusUpdateClosure?

    public init(
        feeAssetId: ChainAssetId?,
        eventsMatcher: ExtrinsicEventsMatching?,
        statusNotificationClosure: ExtrinsicStatusUpdateClosure? = nil
    ) {
        self.feeAssetId = feeAssetId
        self.eventsMatcher = eventsMatcher
        self.statusNotificationClosure = statusNotificationClosure
    }
}

public struct ExtrinsicIndexedSubmissionParams {
    public let feeAssetId: ChainAssetId?
    public let eventsMatcher: ExtrinsicEventsMatching?
    public let statusNotificationClosure: ExtrinsicIndexedStatusUpdateClosure?

    public init(
        feeAssetId: ChainAssetId?,
        eventsMatcher: ExtrinsicEventsMatching?,
        statusNotificationClosure: ExtrinsicIndexedStatusUpdateClosure? = nil
    ) {
        self.feeAssetId = feeAssetId
        self.eventsMatcher = eventsMatcher
        self.statusNotificationClosure = statusNotificationClosure
    }
}
