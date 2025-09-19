import Foundation
import CommonMissing

protocol ExtrinsicSignedExtensionFacadeProtocol {
    func createFactory(for chainId: ChainModel.Id) -> ExtrinsicSignedExtensionFactoryProtocol
}

final class ExtrinsicSignedExtensionFacade {
    public init() { }
}

extension ExtrinsicSignedExtensionFacade: ExtrinsicSignedExtensionFacadeProtocol {
    func createFactory(for _: ChainModel.Id) -> ExtrinsicSignedExtensionFactoryProtocol {
        ExtrinsicSignedExtensionFactory()
    }
}
