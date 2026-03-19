import Foundation
import SubstrateSdk

public enum SubstrateExtrinsicStatus {
    public struct SuccessExtrinsic {
        public let extrinsicHash: ExtrinsicHash
        public let blockHash: BlockHash
        public let blockNumber: BlockNumber
        public let extrinsicIndex: ExtrinsicIndex
        public let interestedEvents: [Event]

        public init(
            extrinsicHash: ExtrinsicHash,
            blockHash: BlockHash,
            blockNumber: BlockNumber,
            extrinsicIndex: ExtrinsicIndex,
            interestedEvents: [Event]
        ) {
            self.extrinsicHash = extrinsicHash
            self.blockHash = blockHash
            self.blockNumber = blockNumber
            self.extrinsicIndex = extrinsicIndex
            self.interestedEvents = interestedEvents
        }
    }
    
    public struct FailedExtrinsic {
        public let extrinsicHash: ExtrinsicHash
        public let blockHash: BlockHash
        public let blockNumber: BlockNumber
        public let extrinsicIndex: ExtrinsicIndex
        public let error: Substrate.DispatchCallError

        public init(
            extrinsicHash: ExtrinsicHash,
            blockHash: BlockHash,
            blockNumber: BlockNumber,
            extrinsicIndex: ExtrinsicIndex,
            error: Substrate.DispatchCallError
        ) {
            self.extrinsicHash = extrinsicHash
            self.blockHash = blockHash
            self.blockNumber = blockNumber
            self.extrinsicIndex = extrinsicIndex
            self.error = error
        }
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
