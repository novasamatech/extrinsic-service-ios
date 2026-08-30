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
                    anchorBlock: BlockNumberWithHash(
                        blockNumber: eraParameters.blockNumber,
                        blockHash: blockHash
                    )
                )
            )
        }
    }
}

public struct MortalExtrinsic {
    public let era: Era
    public let anchorBlock: BlockNumberWithHash

    public init(era: Era, anchorBlock: BlockNumberWithHash) {
        self.era = era
        self.anchorBlock = anchorBlock
    }
}
