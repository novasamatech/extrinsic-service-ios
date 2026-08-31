import Foundation
import SubstrateSdk

public struct BlockNumberWithHash {
    public let blockNumber: BlockNumber
    public let blockHash: BlockHashData

    public init(blockNumber: BlockNumber, blockHash: BlockHashData) {
        self.blockNumber = blockNumber
        self.blockHash = blockHash
    }
}
