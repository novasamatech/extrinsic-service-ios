import Foundation
import Operation_iOS

public protocol RuntimeCodingServiceProtocol {
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol>
}

public protocol RuntimeProviderProtocol: AnyObject, RuntimeCodingServiceProtocol {
    var chainId: ChainModel.Id { get }
    var hasSnapshot: Bool { get }

    func setup()
    func replaceChainData(_ chain: ChainModel)
    func cleanup()
}
