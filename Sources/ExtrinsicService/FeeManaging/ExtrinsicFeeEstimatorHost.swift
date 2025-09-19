import Foundation
import SubstrateSdk
import Operation_iOS
import CommonMissing

public protocol ExtrinsicFeeEstimatorHostProtocol {
    var account: ChainAccountResponse { get }
    var chain: ChainModel { get }
    var connection: JSONRPCEngine { get }
    var runtimeProvider: RuntimeProviderProtocol { get }
    var userStorageFacade: StorageFacadeProtocol { get }
    var substrateStorageFacade: StorageFacadeProtocol { get }
    var operationQueue: OperationQueue { get }
    var logger: LoggerProtocol? { get }
}

public final class ExtrinsicFeeEstimatorHost: ExtrinsicFeeEstimatorHostProtocol {
    public let account: ChainAccountResponse
    public let chain: ChainModel
    public let connection: JSONRPCEngine
    public let runtimeProvider: RuntimeProviderProtocol
    public let userStorageFacade: StorageFacadeProtocol
    public let substrateStorageFacade: StorageFacadeProtocol
    public let operationQueue: OperationQueue
    public let logger: LoggerProtocol?

    public init(
        account: ChainAccountResponse,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.account = account
        self.chain = chain
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.userStorageFacade = userStorageFacade
        self.substrateStorageFacade = substrateStorageFacade
        self.operationQueue = operationQueue
        self.logger = logger
    }
}
