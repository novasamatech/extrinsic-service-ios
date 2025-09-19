import Foundation
import Operation_iOS
import SubstrateSdk
import CommonMissing

public protocol BlockEventsQueryFactoryProtocol {
    func queryBlockDetailsWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data
    ) -> CompoundOperationWrapper<SubstrateBlockDetails>
}

public final class BlockEventsQueryFactory {
    let storageRequestFactory: StorageRequestFactoryProtocol
    let eventsRepository: SubstrateEventsRepositoryProtocol
    let logger: LoggerProtocol?

    public init(
        operationQueue: OperationQueue,
        eventsRepository: SubstrateEventsRepositoryProtocol = SubstrateEventsRepository(),
        storageRequestFactory: StorageRequestFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.storageRequestFactory = storageRequestFactory
        self.eventsRepository = eventsRepository

        self.logger = logger
    }

    private func createEventsWrapper(
        dependingOn coderFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        connection: JSONRPCEngine,
        blockHash: Data
    ) -> CompoundOperationWrapper<StorageResponse<[EventRecord]>> {
        storageRequestFactory.queryItem(
            engine: connection,
            factory: {
                try coderFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: SystemPallet.eventsPath,
            at: blockHash
        )
    }

    private func createBlockFetchOperation(
        for connection: JSONRPCEngine,
        blockHash: Data
    ) -> JSONRPCOperation<[String], SignedBlock> {
        JSONRPCOperation(
            engine: connection,
            method: RPCMethod.getChainBlock,
            parameters: [blockHash.toHex(includePrefix: true)]
        )
    }

    private func createParsingExtrinsicEventsOperation(
        dependingOn eventsOperation: BaseOperation<StorageResponse<[EventRecord]>>,
        blockOperation: BaseOperation<SignedBlock>,
        repository: SubstrateEventsRepositoryProtocol,
        logger: LoggerProtocol?
    ) -> BaseOperation<SubstrateBlockDetails> {
        ClosureOperation {
            let block = try blockOperation.extractNoCancellableResultData().block

            logger?.debug("Block received: \(block)")

            let eventRecords = try eventsOperation.extractNoCancellableResultData().value ?? []

            logger?.debug("Events received: \(eventRecords)")

            let extrinsicsWithEvents = repository.getExtrinsicsEvents(from: block, eventRecords: eventRecords)
            let inherentEvents = repository.getInherentEvents(from: eventRecords)

            return SubstrateBlockDetails(
                extrinsicsWithEvents: extrinsicsWithEvents,
                inherentsEvents: inherentEvents
            )
        }
    }
}

extension BlockEventsQueryFactory: BlockEventsQueryFactoryProtocol {
    public func queryBlockDetailsWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockHash: Data
    ) -> CompoundOperationWrapper<SubstrateBlockDetails> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let eventsWrapper = createEventsWrapper(
            dependingOn: codingFactoryOperation,
            connection: connection,
            blockHash: blockHash
        )

        eventsWrapper.addDependency(operations: [codingFactoryOperation])

        let blockFetchOperation = createBlockFetchOperation(
            for: connection,
            blockHash: blockHash
        )

        let parsingOperation = createParsingExtrinsicEventsOperation(
            dependingOn: eventsWrapper.targetOperation,
            blockOperation: blockFetchOperation,
            repository: eventsRepository,
            logger: logger
        )

        parsingOperation.addDependency(eventsWrapper.targetOperation)
        parsingOperation.addDependency(blockFetchOperation)

        return eventsWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: blockFetchOperation)
            .insertingTail(operation: parsingOperation)
    }
}
