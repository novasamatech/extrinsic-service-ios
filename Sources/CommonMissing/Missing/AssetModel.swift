import Foundation
import SubstrateSdk

public protocol AssetModel {
    typealias Id = UInt32
    typealias Symbol = String

    var assetId: Id { get }
    var symbol: Symbol { get }
    var precision: UInt16 { get }
    var type: String? { get }
}

public extension AssetModel {
    var decimalPrecision: Int16 {
        Int16(bitPattern: precision)
    }
    
    var isUtility: Bool { assetId == 0 }
}
