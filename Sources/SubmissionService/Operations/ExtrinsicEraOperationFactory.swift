import Foundation
import Operation_iOS
import SubstrateSdk

public struct ExtrinsicEraParameters {
    public let blockNumber: BlockNumber
    public let extrinsicEra: Era
    
    public init(blockNumber: BlockNumber, extrinsicEra: Era) {
        self.blockNumber = blockNumber
        self.extrinsicEra = extrinsicEra
    }
}

public protocol ExtrinsicEraOperationFactoryProtocol {
    func createOperation(
        from connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ExtrinsicEraParameters>
}
