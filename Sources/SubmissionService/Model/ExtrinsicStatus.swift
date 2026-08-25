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
        guard case let .onChain(remoteStatus) = extrinsicStatus else {
            return nil
        }

        switch remoteStatus {
        case let .inBlock(blockHash):
            return blockHash
        case let .finalized(blockHash):
            return blockHash
        default:
            return nil
        }
    }

    /// The block hash of the status that is terminal for the requested target.
    /// In `.finalized` mode a bare `inBlock` update is not terminal.
    public func getTerminalBlockHash(trackingTill: ExtrinsicTrackingTill) -> BlockHash? {
        guard case let .onChain(remoteStatus) = extrinsicStatus else {
            return nil
        }

        switch (trackingTill, remoteStatus) {
        case let (.finalized, .finalized(blockHash)):
            return blockHash
        case let (.inBlock, .inBlock(blockHash)),
             let (.inBlock, .finalized(blockHash)):
            return blockHash
        default:
            return nil
        }
    }

    /// The block hash for a provisional `inBlock` inclusion, used in `.finalized`
    /// mode to compute the execution result while finality is still pending.
    public func getInBlockHash() -> BlockHash? {
        guard case let .onChain(.inBlock(blockHash)) = extrinsicStatus else {
            return nil
        }

        return blockHash
    }

    public func getFinalExtrinsicFailure() -> FinalExtrinsicStatusError? {
        guard case let .onChain(remoteStatus) = extrinsicStatus else {
            return nil
        }

        switch remoteStatus {
        case .invalid:
            return .invalid
        case .dropped:
            return .dropped
        case .unsurped:
            return .usurped
        case .finalityTimeout:
            return .finalityTimeout
        default:
            return nil
        }
    }
}

public enum ExtrinsicStatus {
    case created
    case onChain(RemoteExtrinsicStatus)
    /// Provisional execution result surfaced at inclusion time while finality is
    /// still pending (only emitted in `ExtrinsicTrackingTill.finalized` mode).
    case executed(ExtrinsicExecution)
}

// https://paritytech.github.io/polkadot-sdk/master/src/sc_transaction_pool_api/lib.rs.html#130
public enum RemoteExtrinsicStatus: Decodable, Equatable {
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
    case usurped
}
