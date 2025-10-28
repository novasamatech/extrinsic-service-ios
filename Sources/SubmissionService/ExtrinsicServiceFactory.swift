import Foundation
import SubstrateSdk

public protocol ExtrinsicServiceFactoryProtocol {
    func createOperationFactory(
        from wallet: MetaAccountModelProtocol,
        chain: ChainProtocol
    ) throws -> ExtrinsicOperationFactoryProtocol
    
    func createExtrinsicService(
        from wallet: MetaAccountModelProtocol,
        chain: ChainProtocol
    ) throws -> ExtrinsicServiceProtocol
}
