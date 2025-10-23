import Foundation
import SubstrateSdk

public protocol ExtrinsicOriginDefiningFactoryProtocol {
    func extrinsicOriginDefiner(
        from wallet: MetaAccountModelProtocol,
        chain: ChainProtocol
    ) throws -> ExtrinsicOriginDefining
}
