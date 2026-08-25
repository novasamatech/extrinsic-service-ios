import Foundation
import SubstrateSdk

/// Provisional execution result reported when an extrinsic is included in a block
/// while its finalization is still pending (see `ExtrinsicTrackingTill.finalized`).
public struct ExtrinsicExecution {
    public let blockHash: BlockHash
    public let dispatchStatus: DispatchStatus

    public init(blockHash: BlockHash, dispatchStatus: DispatchStatus) {
        self.blockHash = blockHash
        self.dispatchStatus = dispatchStatus
    }
}
