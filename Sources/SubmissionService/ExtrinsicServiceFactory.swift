import Foundation
import SubstrateSdk

public protocol ExtrinsicServiceFactoryProtocol {
    func createOperationFactory(chain: ChainProtocol) throws -> ExtrinsicOperationFactoryProtocol
    func createExtrinsicService(chain: ChainProtocol) throws -> ExtrinsicServiceProtocol
}
