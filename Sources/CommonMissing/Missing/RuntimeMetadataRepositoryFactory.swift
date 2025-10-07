import Foundation
import Operation_iOS

public protocol RuntimeMetadataRepositoryFactoryProtocol {
    func createRepository() -> AnyDataProviderRepository<RuntimeMetadataItem>
    func createRepository(for chainId: ChainId) -> AnyDataProviderRepository<RuntimeMetadataItem>
}
