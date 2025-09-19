import Foundation
import Operation_iOS

public protocol RuntimeMetadataRepositoryFactoryProtocol {
    func createRepository() -> AnyDataProviderRepository<RuntimeMetadataItem>
    func createRepository(for chainId: ChainModel.Id) -> AnyDataProviderRepository<RuntimeMetadataItem>
}

//public final class RuntimeMetadataRepositoryFactory {
//    let storageFacade: StorageFacadeProtocol
//
//    public init(storageFacade: StorageFacadeProtocol) {
//        self.storageFacade = storageFacade
//    }
//}
//
//public extension RuntimeMetadataRepositoryFactory: RuntimeMetadataRepositoryFactoryProtocol {
//    func createRepository() -> AnyDataProviderRepository<RuntimeMetadataItem> {
//        let repository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem>
//        repository = storageFacade.createRepository()
//
//        return AnyDataProviderRepository(repository)
//    }
//
//    func createRepository(for chainId: ChainModel.Id) -> AnyDataProviderRepository<RuntimeMetadataItem> {
//        let repository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> = storageFacade.createRepository(
//            filter: NSPredicate.filterRuntimeMetadataItemsBy(identifier: chainId)
//        )
//
//        return AnyDataProviderRepository(repository)
//    }
//}
