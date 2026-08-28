import Foundation
import SubstrateSdk

public struct ExtrinsicSubmissionParams {
    public let feeAssetId: ChainAssetId?
    public let eventsMatcher: ExtrinsicEventsMatching?
    public let trackingTill: ExtrinsicTrackingTill
    public let statusNotificationClosure: ExtrinsicStatusUpdateClosure?

    public init(
        feeAssetId: ChainAssetId?,
        eventsMatcher: ExtrinsicEventsMatching?,
        trackingTill: ExtrinsicTrackingTill = .inBlock,
        statusNotificationClosure: ExtrinsicStatusUpdateClosure? = nil
    ) {
        self.feeAssetId = feeAssetId
        self.eventsMatcher = eventsMatcher
        self.trackingTill = trackingTill
        self.statusNotificationClosure = statusNotificationClosure
    }
}

public struct ExtrinsicIndexedSubmissionParams {
    public let feeAssetId: ChainAssetId?
    public let eventsMatcher: ExtrinsicEventsMatching?
    public let trackingTill: ExtrinsicTrackingTill
    public let statusNotificationClosure: ExtrinsicIndexedStatusUpdateClosure?

    public init(
        feeAssetId: ChainAssetId?,
        eventsMatcher: ExtrinsicEventsMatching?,
        trackingTill: ExtrinsicTrackingTill = .inBlock,
        statusNotificationClosure: ExtrinsicIndexedStatusUpdateClosure? = nil
    ) {
        self.feeAssetId = feeAssetId
        self.eventsMatcher = eventsMatcher
        self.trackingTill = trackingTill
        self.statusNotificationClosure = statusNotificationClosure
    }
}
