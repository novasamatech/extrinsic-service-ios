import Foundation
import Operation_iOS

public protocol StorageFacadeProtocol: AnyObject {
    var databaseService: CoreDataServiceProtocol { get }

//    func createRepository<T, U>(
//        filter: NSPredicate?,
//        sortDescriptors: [NSSortDescriptor],
//        mapper: AnyCoreDataMapper<T, U>
//    ) -> CoreDataRepository<T, U>
//        where T: Identifiable, U: NSManagedObject
}
