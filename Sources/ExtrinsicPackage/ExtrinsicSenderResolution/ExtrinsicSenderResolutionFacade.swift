import Foundation
import Operation_iOS
import CommonMissing

public protocol ExtrinsicSenderResolutionFacadeProtocol {
    func createResolutionFactory(
        for chainAccount: ChainAccountResponse,
        chainModel: ChainModel
    ) -> ExtrinsicSenderResolutionFactoryProtocol
}

public final class ExtrinsicSenderResolutionFacade {
    let accountProvider: MetaAccountProviding

    public init(accountProvider: MetaAccountProviding) {
        self.accountProvider = accountProvider
    }
}

extension ExtrinsicSenderResolutionFacade: ExtrinsicSenderResolutionFacadeProtocol {
    public func createResolutionFactory(
        for chainAccount: ChainAccountResponse,
        chainModel: ChainModel
    ) -> ExtrinsicSenderResolutionFactoryProtocol {
        ExtrinsicSenderResolutionFactory(
            chainAccount: chainAccount,
            chain: chainModel,
            accountProvider: accountProvider,
        )
    }
}
