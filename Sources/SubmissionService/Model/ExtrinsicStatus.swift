import Foundation
import SubstrateSdk

public struct ExtrinsicStatusUpdate {
    public let extrinsicHash: String
    public let extrinsicStatus: ExtrinsicStatus

    init(extrinsicHash: String, extrinsicStatus: ExtrinsicStatus) {
        self.extrinsicHash = extrinsicHash
        self.extrinsicStatus = extrinsicStatus
    }
    
    public func getInBlockOrFinalizedHash() -> BlockHash? {
        switch extrinsicStatus {
        case let .inBlock(blockHash):
            blockHash
        case let .finalized(blockHash):
            blockHash
        default:
            nil
        }
    }
    
    public func getFinalExtrinsicFailure() -> FinalExtrinsicStatusError? {
        switch extrinsicStatus {
        case .invalid:
            .invalid
        case .dropped:
            .dropped
        case .finalityTimeout:
            .finalityTimeout
        default:
            nil
        }
    }
}

// https://paritytech.github.io/polkadot-sdk/master/src/sc_transaction_pool_api/lib.rs.html#130
public enum ExtrinsicStatus: Decodable, Equatable {
    case future // waiting for lesser nonce
    case ready // ready for execution
    case broadcast([String]) // broadcasted to peers
    case inBlock(BlockHash) // included into block
    case retracted(BlockHash) // block in which extrinsic included was retracted
    case finalized(BlockHash) // block with extrinsic finalized
    case finalityTimeout(BlockHash) // finalization for block with extrinsic timed out
    case unsurped(ExtrinsicHash) // extrinsic was replaced with another one with different (sender, nonce)
    case dropped // transaction has been dropped from the pool because of limits
    case invalid // final state, extrinsic can appear in the pool only after resubmission
    case other

    private enum ValueKeys: String {
        case future, ready, dropped, invalid
    }
    
    private enum DictKeys: String, CodingKey {
        case broadcast, inBlock, retracted, finalityTimeout, finalized, usurped
    }

    public init(from decoder: Decoder) throws {
        if let dictContainer = try? decoder.container(keyedBy: DictKeys.self) {
            if let peers = try dictContainer.decodeIfPresent([String].self, forKey: .broadcast) {
                self = .broadcast(peers)
            } else if let blockHash = try dictContainer.decodeIfPresent(BlockHash.self, forKey: .inBlock) {
                self = .inBlock(blockHash)
            } else if let blockHash = try dictContainer.decodeIfPresent(BlockHash.self, forKey: .retracted) {
                self = .retracted(blockHash)
            } else if let blockHash = try dictContainer.decodeIfPresent(BlockHash.self, forKey: .finalityTimeout) {
                self = .finalityTimeout(blockHash); return
            } else if let blockHash = try dictContainer.decodeIfPresent(BlockHash.self, forKey: .finalized) {
                self = .finalized(blockHash)
            } else if let extHash = try dictContainer.decodeIfPresent(ExtrinsicHash.self, forKey: .usurped) {
                self = .unsurped(extHash)
            } else {
                self = .other
            }
        } else if let valueType = try? decoder.singleValueContainer().decode(String.self) {
            switch ValueKeys(rawValue: valueType) {
            case .future:
                self = .future
            case .ready:
                self = .ready
            case .invalid:
                self = .invalid
            case .dropped:
                self = .dropped
            case nil:
                self = .other
            }
        } else {
            self = .other
        }
    }
}

public enum FinalExtrinsicStatusError: Error {
    case finalityTimeout
    case invalid
    case dropped
}
