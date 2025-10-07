import Foundation
import SubstrateSdk
import Operation_iOS
import CommonMissing

public protocol ExtrinsicFeeEstimatorHostProtocol {
    var account: AccountProtocol { get }
    var chain: ChainModel { get }
    var connection: JSONRPCEngine { get }
    var runtimeProvider: RuntimeProviderProtocol { get }
    var operationQueue: OperationQueue { get }
    var logger: LoggerProtocol? { get }
}

public final class ExtrinsicFeeEstimatorHost: ExtrinsicFeeEstimatorHostProtocol {
    public let account: AccountProtocol
    public let chain: ChainModel
    public let connection: JSONRPCEngine
    public let runtimeProvider: RuntimeProviderProtocol
    public let operationQueue: OperationQueue
    public let logger: LoggerProtocol?

    public init(
        account: AccountProtocol,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.account = account
        self.chain = chain
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.logger = logger
    }
}
