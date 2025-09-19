import Foundation
import Operation_iOS
import CommonMissing

public protocol MetaAccountProviding {
    func accounts() -> BaseOperation<[MetaAccountModel]>
}
