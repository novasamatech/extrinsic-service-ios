import Foundation
import SubstrateSdk

public enum SubstrateExtrinsicStatus {
    public struct SuccessExtrinsic {
        let extrinsicHash: ExtrinsicHash
        let blockHash: BlockHash
        let interestedEvents: [Event]
    }

    public struct FailedExtrinsic {
        let extrinsicHash: ExtrinsicHash
        let blockHash: BlockHash
        let error: Substrate.DispatchCallError
    }

    case success(SuccessExtrinsic)
    case failure(FailedExtrinsic)
}

public extension Result where Success == SubstrateExtrinsicStatus {
    func getSuccessExtrinsicStatus() throws -> SubstrateExtrinsicStatus.SuccessExtrinsic {
        let executionStatus = try get()

        switch executionStatus {
        case let .success(successStatus):
            return successStatus
        case let .failure(failureStature):
            throw failureStature.error
        }
    }
}
