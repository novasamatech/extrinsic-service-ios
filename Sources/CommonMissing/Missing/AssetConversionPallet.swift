import Foundation
import SubstrateSdk
import BigInt

public enum AssetConversionPallet {
    static let name = "AssetConversion"

    public typealias AssetId = Xcm.Version4<XcmUni.AssetId>
}
