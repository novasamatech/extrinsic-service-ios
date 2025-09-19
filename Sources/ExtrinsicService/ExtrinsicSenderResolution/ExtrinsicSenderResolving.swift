import Foundation
import SubstrateSdk
import CommonMissing

public enum ExtrinsicSenderResolution {
    public struct ResolutionDelegateFailure {
        public let callPath: CallCodingPath
        public let paths: DelegationResolution.GraphResult
    }

    public struct ResolvedDelegate {
        public let delegateAccount: MetaChainAccountResponse?
        public let delegatedAccount: ChainAccountResponse
        public let paths: [JSON: DelegationResolution.PathFinderPath]
        public let allWallets: [MetaAccountModel]
        public let chain: ChainModel
        public let failures: [ResolutionDelegateFailure]

        var canSignWithDelegate: Bool {
            guard failures.isEmpty, let delegateAccount else {
                return false
            }

            return !delegateAccount.chainAccount.delegated
        }

        func getNonResolvedProxiedWallet() -> MetaAccountModel? {
            guard !canSignWithDelegate else {
                return nil
            }

            if let delegateAccount {
                guard delegateAccount.chainAccount.isProxied else {
                    return nil
                }

                return allWallets.first(where: { $0.metaId == delegateAccount.metaId })
            } else if delegatedAccount.isProxied {
                return allWallets.first(where: { $0.metaId == delegatedAccount.metaId })
            } else {
                return nil
            }
        }

        func getNotEnoughPermissionProxyWallet() -> MetaAccountModel? {
            guard
                let proxiedWallet = getNonResolvedProxiedWallet(),
                let proxyModel = proxiedWallet.proxy else {
                return nil
            }

            let accountRequest = chain.accountRequest()

            return allWallets.first {
                $0.fetch(for: accountRequest)?.accountId == proxyModel.accountId
            }
        }
    }

    case current(ChainAccountResponse)
    case delegate(ResolvedDelegate)

    public var account: ChainAccountResponse {
        switch self {
        case let .current(account):
            return account
        case let .delegate(delegate):
            return delegate.delegateAccount?.chainAccount ?? delegate.delegatedAccount
        }
    }
}

public typealias ExtrinsicSenderBuilderResolution = (sender: ExtrinsicSenderResolution, builders: [ExtrinsicBuilderProtocol])

public protocol ExtrinsicSenderResolving: AnyObject {
    func resolveSender(
        wrapping builders: [ExtrinsicBuilderProtocol],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicSenderBuilderResolution
}

final class ExtrinsicCurrentSenderResolver: ExtrinsicSenderResolving {
    let currentAccount: ChainAccountResponse

    init(currentAccount: ChainAccountResponse) {
        self.currentAccount = currentAccount
    }

    func resolveSender(
        wrapping builders: [ExtrinsicBuilderProtocol],
        codingFactory _: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicSenderBuilderResolution {
        (.current(currentAccount), builders)
    }
}
