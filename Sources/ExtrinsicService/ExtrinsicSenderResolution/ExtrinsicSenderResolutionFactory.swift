import Foundation
import Operation_iOS
import SubstrateSdk

public protocol ExtrinsicSenderResolutionFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<ExtrinsicSenderResolving>
}

public final class ExtrinsicSenderResolutionFactory {
    let account: AccountProtocol
    
    public init(account: AccountProtocol) {
        self.account = account
    }
}

extension ExtrinsicSenderResolutionFactory: ExtrinsicSenderResolutionFactoryProtocol {
    public func createWrapper() -> CompoundOperationWrapper<ExtrinsicSenderResolving> {
        let resolver = ExtrinsicCurrentSenderResolver(currentAccount: account)
        return CompoundOperationWrapper.createWithResult(resolver)
    }
}
