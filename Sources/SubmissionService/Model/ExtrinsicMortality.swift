import Foundation
import SubstrateSdk

public enum ExtrinsicMortality {
    case immortal
    case mortal(MortalExtrinsic)

    public init(eraParameters: ExtrinsicEraParameters, blockHash: BlockHashData) {
        switch eraParameters.extrinsicEra {
        case .immortal:
            self = .immortal
        case .mortal:
            self = .mortal(
                MortalExtrinsic(
                    era: eraParameters.extrinsicEra,
                    blockNumber: eraParameters.blockNumber,
                    blockHash: blockHash
                )
            )
        }
    }
}

public struct MortalExtrinsic {
    public let era: Era
    public let blockNumber: BlockNumber
    public let blockHash: BlockHashData

    public init(era: Era, blockNumber: BlockNumber, blockHash: BlockHashData) {
        self.era = era
        self.blockNumber = blockNumber
        self.blockHash = blockHash
    }
}
