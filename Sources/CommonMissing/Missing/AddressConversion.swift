import Foundation
import NovaCrypto

public struct SubstrateConstants {
//    static let maxNominations: UInt32 = 16
    static let accountIdLength = 32
    static let ethereumAddressLength = 20
//    static let paraIdLength = 4
//    static let paraIdType = PrimitiveType.u32.name
//    static let maxUnbondingRequests = 32
    static let genericAddressPrefix: UInt16 = 42
    static let multichainDisplayPrefix: UInt16 = 0
}


public enum ChainFormat {
    case ethereum
    case substrate(_ prefix: UInt16, legacyPrefix: UInt16? = nil)
}

public extension AccountId {
    func toAddress(using conversion: ChainFormat) throws -> AccountAddress {
        switch conversion {
        case .ethereum:
            toHex(includePrefix: true)
        case let .substrate(prefix, _):
            try SS58AddressFactory().address(
                fromAccountId: self,
                type: prefix
            )
        }
    }
}

public extension ChainModel {
    var chainFormat: ChainFormat {
        if isEthereumBased {
            .ethereum
        } else {
            .substrate(
                addressPrefix.toSubstrateFormat(),
                legacyPrefix: nil// legacyAddressPrefix?.toSubstrateFormat()
            )
        }
    }
}
