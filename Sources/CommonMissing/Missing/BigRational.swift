import Foundation
import BigInt

public struct BigRational: Hashable, Equatable {
    let numerator: BigUInt
    let denominator: BigUInt

    func mul(value: BigUInt) -> BigUInt {
        value * numerator / denominator
    }
}
