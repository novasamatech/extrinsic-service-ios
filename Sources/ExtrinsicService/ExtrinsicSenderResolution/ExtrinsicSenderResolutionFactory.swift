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
}

extension ExtrinsicSenderResolutionFactory: ExtrinsicSenderResolutionFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<ExtrinsicSenderResolving> {
        createCurrentResolver(for: chainAccount)
    }
}
