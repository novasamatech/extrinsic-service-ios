import Foundation
import Operation_iOS
import CommonMissing

public protocol ExtrinsicSenderResolutionFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<ExtrinsicSenderResolving>
}

final class ExtrinsicSenderResolutionFactory {
    let chain: ChainModel
    let chainAccount: ChainAccountResponse
    let accountProvider: MetaAccountProviding
    
    public init(
        chainAccount: ChainAccountResponse,
        chain: ChainModel,
        accountProvider: MetaAccountProviding
    ) {
        self.chainAccount = chainAccount
        self.chain = chain
        self.accountProvider = accountProvider
    }

    private func createCurrentResolver(
        for chainAccount: ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicSenderResolving> {
        let resolver = ExtrinsicCurrentSenderResolver(currentAccount: chainAccount)
        return CompoundOperationWrapper.createWithResult(resolver)
    }

    private func createDelegateResolver(
        for delegatedAccount: ChainAccountResponse,
        chain: ChainModel
    ) -> CompoundOperationWrapper<ExtrinsicSenderResolving> {
        let fetchOperation = accountProvider.accounts()
        
        let mappingOperation = ClosureOperation<ExtrinsicSenderResolving> {
            let wallets = try fetchOperation.extractNoCancellableResultData()
            
            guard let delegateAccountId = wallets.first(
                where: { $0.metaId == delegatedAccount.metaId }
            )?.getDelegateIdentifier()?.delegateAccountId
            else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let callWrapper = try DelegatedCallWrapperFactory.createCallWrapper(
                for: delegatedAccount,
                delegateAccountId: delegateAccountId
            )

            return ExtrinsicDelegateSenderResolver(
                delegatedAccount: delegatedAccount,
                delegateAccountId: delegateAccountId,
                callWrapper: callWrapper,
                wallets: wallets,
                chain: chain
            )
        }

        mappingOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [fetchOperation])
    }
}

extension ExtrinsicSenderResolutionFactory: ExtrinsicSenderResolutionFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<ExtrinsicSenderResolving> {
        switch chainAccount.type {
        case .secrets, .paritySigner, .polkadotVault, .ledger, .watchOnly, .genericLedger:
            createCurrentResolver(for: chainAccount)
        case .proxied, .multisig:
            createDelegateResolver(
                for: chainAccount,
                chain: chain
            )
        }
    }
}
