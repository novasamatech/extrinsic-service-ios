import Foundation

public enum ChainAccountFetchingError: Error {
    case accountNotExists
}

public struct ChainAccountRequest: Equatable, Hashable {
    let chainId: ChainModel.Id
    let addressPrefix: ChainModel.AddressPrefix
    let isEthereumBased: Bool
    let supportsGenericLedger: Bool
    let supportsMultisigs: Bool
}

public struct ChainAccountResponse {
    public let metaId: String
    public let chainId: ChainModel.Id
    public let accountId: AccountId
    public let publicKey: Data
    public let name: String
    public let cryptoType: MultiassetCryptoType
    public let addressPrefix: ChainModel.AddressPrefix
    public let isEthereumBased: Bool
    public let isChainAccount: Bool
    public let type: MetaAccountModelType
    
    public init(
        metaId: String,
        chainId: ChainModel.Id,
        accountId: AccountId,
        publicKey: Data,
        name: String,
        cryptoType: MultiassetCryptoType,
        addressPrefix: ChainModel.AddressPrefix,
        isEthereumBased: Bool,
        isChainAccount: Bool,
        type: MetaAccountModelType
    ) {
        self.metaId = metaId
        self.chainId = chainId
        self.accountId = accountId
        self.publicKey = publicKey
        self.name = name
        self.cryptoType = cryptoType
        self.addressPrefix = addressPrefix
        self.isEthereumBased = isEthereumBased
        self.isChainAccount = isChainAccount
        self.type = type
    }
}

public struct MetaChainAccountResponse {
    public let metaId: String
    public let substrateAccountId: AccountId?
    public let ethereumAccountId: AccountId?
    public let walletIdenticonData: Data?
    public let delegationId: DelegateIdentifier?
    public let chainAccount: ChainAccountResponse
}

public extension MetaAccountModel {
    func has(accountId: AccountId, chainId: ChainModel.Id) -> Bool {
        if let chainAccount = chainAccounts.first(where: { $0.chainId == chainId }) {
            chainAccount.accountId == accountId
        } else {
            substrateAccountId == accountId || ethereumAddress == accountId
        }
    }
}

extension ChainAccountResponse {
    public var chainFormat: ChainFormat {
        isEthereumBased
            ? .ethereum
            : .substrate(addressPrefix.toSubstrateFormat())
    }
    
    public var delegated: Bool {
        type == .proxied || type == .multisig
    }
    
    public var isProxied: Bool {
        type == .proxied
    }
}

extension MetaAccountModel {
    private func executeHasAccount(for chain: ChainModel) -> Bool {
        if chainAccounts.contains(where: { $0.chainId == chain.chainId }) {
            return true
        }

        if chain.isEthereumBased {
            return ethereumAddress != nil
        }

        return substrateAccountId != nil
    }

    private func executeFetch(request: ChainAccountRequest) -> ChainAccountResponse? {
        if let chainAccount = chainAccounts.first(where: { $0.chainId == request.chainId }) {
            guard let cryptoType = MultiassetCryptoType(rawValue: chainAccount.cryptoType) else {
                return nil
            }

            return ChainAccountResponse(
                metaId: metaId,
                chainId: request.chainId,
                accountId: chainAccount.accountId,
                publicKey: chainAccount.publicKey,
                name: name,
                cryptoType: cryptoType,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased,
                isChainAccount: true,
                type: type
            )
        }

        if request.isEthereumBased {
            guard let publicKey = ethereumPublicKey, let accountId = ethereumAddress else {
                return nil
            }

            return ChainAccountResponse(
                metaId: metaId,
                chainId: request.chainId,
                accountId: accountId,
                publicKey: publicKey,
                name: name,
                cryptoType: MultiassetCryptoType.ethereumEcdsa,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased,
                isChainAccount: false,
                type: type
            )
        }

        guard
            let substrateCryptoType = substrateCryptoType,
            let substrateAccountId = substrateAccountId,
            let substratePublicKey = substratePublicKey,
            let cryptoType = MultiassetCryptoType(rawValue: substrateCryptoType) else {
            return nil
        }

        return ChainAccountResponse(
            metaId: metaId,
            chainId: request.chainId,
            accountId: substrateAccountId,
            publicKey: substratePublicKey,
            name: name,
            cryptoType: cryptoType,
            addressPrefix: request.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false,
            type: type
        )
    }

    public func fetch(for request: ChainAccountRequest) -> ChainAccountResponse? {
        switch type {
        case .genericLedger:
            if request.supportsGenericLedger {
                return executeFetch(request: request)
            } else {
                return nil
            }
        case .secrets, .ledger, .paritySigner, .polkadotVault, .proxied, .watchOnly:
            return executeFetch(request: request)
        case .multisig:
            if request.supportsMultisigs {
                return executeFetch(request: request)
            } else {
                return nil
            }
        }
    }

    func hasAccount(in chain: ChainModel) -> Bool {
        switch type {
        case .genericLedger:
            if chain.supportsGenericLedgerApp {
                return executeHasAccount(for: chain)
            } else {
                return false
            }
        case .secrets, .ledger, .paritySigner, .polkadotVault, .proxied, .watchOnly:
            return executeHasAccount(for: chain)
        case .multisig:
            if chain.hasMultisig {
                return executeHasAccount(for: chain)
            } else {
                return false
            }
        }
    }

    public func fetchMetaChainAccount(for request: ChainAccountRequest) -> MetaChainAccountResponse? {
        fetch(for: request).map {
            MetaChainAccountResponse(
                metaId: metaId,
                substrateAccountId: substrateAccountId,
                ethereumAccountId: ethereumAddress,
                walletIdenticonData: walletIdenticonData(),
                delegationId: getDelegateIdentifier(),
                chainAccount: $0
            )
        }
    }

    func fetchChainAccountId(for request: ChainAccountRequest) -> AccountId? {
        chainAccounts.first(where: { $0.chainId == request.chainId })?.accountId
    }

    func contains(accountId: AccountId) -> Bool {
        substrateAccountId == accountId ||
            ethereumAddress == accountId ||
            chainAccounts.contains(where: { $0.accountId == accountId })
    }
}

public extension ChainModel {
    func accountRequest() -> ChainAccountRequest {
        ChainAccountRequest(
            chainId: chainId,
            addressPrefix: addressPrefix,
            isEthereumBased: isEthereumBased,
            supportsGenericLedger: supportsGenericLedgerApp,
            supportsMultisigs: hasMultisig
        )
    }
}
