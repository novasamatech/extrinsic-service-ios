import Foundation
import Operation_iOS

public enum MetaAccountModelType: UInt8 {
    case secrets
    case watchOnly
    case paritySigner
    case ledger
    case polkadotVault
    case proxied
    case genericLedger
    case multisig

    var canPerformOperations: Bool {
        switch self {
        case .secrets,
             .paritySigner,
             .polkadotVault,
             .ledger,
             .proxied,
             .genericLedger,
             .multisig:
            true
        case .watchOnly:
            false
        }
    }

    public var isDelegated: Bool {
        self == .proxied || self == .multisig
    }
}

public extension MetaAccountModelType {
    static func getDisplayPriorities() -> [MetaAccountModelType] {
        [
            .secrets,
            .polkadotVault,
            .paritySigner,
            .ledger,
            .proxied,
            .multisig,
            .watchOnly
        ]
    }
}

public struct MetaAccountModel: Equatable, Hashable {
    // swiftlint:disable:next type_name
    public typealias Id = String

    public let metaId: Id
    public let name: String
    public let substrateAccountId: Data?
    public let substrateCryptoType: UInt8?
    public let substratePublicKey: Data?
    public let ethereumAddress: Data?
    public let ethereumPublicKey: Data?
    public let chainAccounts: Set<ChainAccountModel>
    public let type: MetaAccountModelType
    public let multisig: DelegatedAccount.MultisigAccountModel?
}

extension MetaAccountModel: Operation_iOS.Identifiable {
    public var identifier: String { metaId }
}
