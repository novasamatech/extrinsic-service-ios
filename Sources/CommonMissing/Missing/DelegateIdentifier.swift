import Foundation

public struct DelegateIdentifier: Hashable {
    public let delegatorAccountId: AccountId
    public let delegateAccountId: AccountId
    public let delegateType: DelegationType

    var chainId: ChainModel.Id? {
        switch delegateType {
        case let .proxy(model):
            model.chainId
        case let .multisig(model):
            model.chainId
        }
    }

    func existsInChainWithId(_ identifier: ChainModel.Id) -> Bool {
        chainId == nil || chainId == identifier
    }
}

public enum DelegationType: Hashable, Equatable {
    public enum MultisigModel: Hashable, Equatable {
        case uniSubstrate
        case uniEvm
        case singleChain(ChainModel.Id)

        var chainId: ChainModel.Id? {
            switch self {
            case .uniSubstrate, .uniEvm:
                return nil
            case let .singleChain(chainId):
                return chainId
            }
        }
    }

    public struct ProxyModel: Hashable, Equatable {
        let type: Proxy.ProxyType
        let chainId: ChainModel.Id
    }

    case proxy(ProxyModel)
    case multisig(MultisigModel)

    var delegationClass: DelegationClass {
        switch self {
        case .proxy:
            return .proxy
        case .multisig:
            return .multisig
        }
    }
}

public enum DelegationClass: Equatable {
    case proxy
    case multisig
}
