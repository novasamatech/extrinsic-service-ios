import Foundation
import SubstrateSdk
import Operation_iOS

public protocol ExtrinsicFeeEstimatorHostProtocol {
    var account: AccountProtocol { get }
    var chain: ChainProtocol { get }
    var connection: JSONRPCEngine { get }
    var runtimeProvider: RuntimeCodingServiceProtocol { get }
    var operationQueue: OperationQueue { get }
    var logger: SDKLoggerProtocol? { get }
}

public final class ExtrinsicFeeEstimatorHost: ExtrinsicFeeEstimatorHostProtocol {
    public let account: AccountProtocol
    public let chain: ChainProtocol
    public let connection: JSONRPCEngine
    public let runtimeProvider: RuntimeCodingServiceProtocol
    public let operationQueue: OperationQueue
    public let logger: SDKLoggerProtocol?

    public init(
        account: AccountProtocol,
        chain: ChainProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        logger: SDKLoggerProtocol? = nil
    ) {
        self.account = account
        self.chain = chain
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.logger = logger
    }
}
