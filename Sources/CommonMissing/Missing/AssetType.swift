import Foundation

public enum AssetType: String {
    case statemine
    case orml
    case evmAsset = "evm"
    case evmNative
    case equilibrium
    case ormlHydrationEvm = "orml-hydration-evm"

    public init?(rawType: String?) {
        if let rawType {
            self.init(rawValue: rawType)
        } else {
            return nil
        }
    }
}
