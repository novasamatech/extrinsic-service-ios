import Foundation
import SubstrateSdk
import BigInt

public enum BagList {
    static var defaultModuleName: String {
        "VoterList"
    }

    static var possibleModuleNames: [String] {
        [defaultModuleName, "BagsList"]
    }

    public typealias Score = BigUInt

    public struct Node: Codable, Equatable {
        @StringCodable var bagUpper: Score
        @StringCodable var score: Score
    }

    // Provided by chain (UInt64.max)
    static let maxScore = BigUInt("18446744073709551615")

    static func scoreFactor(for totalIssuance: BigUInt) -> BigUInt {
        max(totalIssuance / maxScore, BigUInt(1))
    }

    static func scoreOf(stake: BigUInt, given factor: BigUInt) -> Score {
        stake / factor
    }

    static func scoreOf(stake: BigUInt, totalIssuance: BigUInt) -> Score {
        let factor = scoreFactor(for: totalIssuance)
        return scoreOf(stake: stake, given: factor)
    }

    static func stake(score: Score, totalIssuance: BigUInt) -> BigUInt {
        let factor = scoreFactor(for: totalIssuance)
        return factor * score
    }
}
