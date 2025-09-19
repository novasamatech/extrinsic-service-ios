import Foundation
import Operation_iOS
import SubstrateSdk
import CommonMissing

struct ExtrinsicEraParameters {
    let blockNumber: BlockNumber
    let extrinsicEra: Era
}

protocol ExtrinsicEraOperationFactoryProtocol {
    func createOperation(
        from connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ExtrinsicEraParameters>
}
