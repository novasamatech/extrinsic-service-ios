import Foundation
import Operation_iOS

public struct ChainAccountModel: Hashable {
    public let chainId: String
    public let accountId: Data
    public let publicKey: Data
    public let cryptoType: UInt8

    var isEthereumBased: Bool {
        cryptoType == MultiassetCryptoType.ethereumEcdsa.rawValue
    }
}

extension ChainAccountModel: Operation_iOS.Identifiable {
    public var identifier: String {
        [
            chainId,
            accountId.toHex(),
            "\(cryptoType)"
        ].joined(separator: "-")
    }
}
