import Foundation
import Operation_iOS
import CommonMissing

public protocol ExtrinsicSenderResolutionFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<ExtrinsicSenderResolving>
}

final class ExtrinsicSenderResolutionFactory {
    let chain: ChainModel
    let account: AccountProtocol
    
    public init(account: AccountProtocol, chain: ChainModel) {
        self.account = account
        self.chain = chain
    }
}

extension ExtrinsicSenderResolutionFactory: ExtrinsicSenderResolutionFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<ExtrinsicSenderResolving> {
        let resolver = ExtrinsicCurrentSenderResolver(currentAccount: account)
        return CompoundOperationWrapper.createWithResult(resolver)
    }
}
