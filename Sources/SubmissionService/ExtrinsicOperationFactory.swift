import Foundation
import Operation_iOS
import SubstrateSdk
import NovaCrypto
import BigInt
import SubstrateMetadataHash

enum ExtrinsicOperationFactoryError: Error {
    case missingSender
}

public final class ExtrinsicOperationFactory: BaseExtrinsicOperationFactory {
    let chain: ChainProtocol
    let customExtensions: [TransactionExtending]
    let eraOperationFactory: ExtrinsicEraOperationFactoryProtocol
    let metadataHashOperationFactory: MetadataHashOperationFactoryProtocol
    let extrinsicVersion: Extrinsic.Version

    public init(
        chain: ChainProtocol,
        extrinsicVersion: Extrinsic.Version,
        feeEstimationRegistry: ExtrinsicFeeEstimationRegistring,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        customExtensions: [TransactionExtending],
        engine: JSONRPCEngine,
        metadataHashOperationFactory: MetadataHashOperationFactoryProtocol,
        eraOperationFactory: ExtrinsicEraOperationFactoryProtocol,
        operationQueue: OperationQueue,
        timeout: Int
    ) {
        self.chain = chain
        self.extrinsicVersion = extrinsicVersion
        self.customExtensions = customExtensions
        self.metadataHashOperationFactory = metadataHashOperationFactory
        self.eraOperationFactory = eraOperationFactory

        super.init(
            feeEstimationRegistry: feeEstimationRegistry,
            runtimeRegistry: runtimeRegistry,
            engine: engine,
            operationQueue: operationQueue,
            timeout: timeout
        )
    }

    private func createBlockHashOperation(
        connection: JSONRPCEngine,
        for numberClosure: @escaping () throws -> BlockNumber
    ) -> BaseOperation<String> {
        let requestOperation = JSONRPCListOperation<String>(
            engine: connection,
            method: RPCMethod.getBlockHash,
            timeout: timeout
        )

        requestOperation.configurationBlock = {
            do {
                let blockNumber = try numberClosure()
                requestOperation.parameters = [blockNumber.toHex()]
            } catch {
                requestOperation.result = .failure(error)
            }
        }

        return requestOperation
    }

    private func createPartialBuildersWrapper(
        customClosure: @escaping ExtrinsicBuilderIndexedClosure,
        indexes: [Int],
        chain: ChainProtocol,
        extrinsicVersion: Extrinsic.Version,
        customExtensions: [TransactionExtending],
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<PartialBuildersModel> {
        let genesisBlockOperation = createBlockHashOperation(connection: engine, for: { 0 })

        let eraWrapper = eraOperationFactory.createOperation(from: engine, runtimeService: runtimeRegistry)

        let eraBlockOperation = createBlockHashOperation(connection: engine) {
            try eraWrapper.targetOperation.extractNoCancellableResultData().blockNumber
        }

        eraBlockOperation.addDependency(eraWrapper.targetOperation)

        let metadataHashWrapper = metadataHashOperationFactory.createCheckMetadataHashWrapper(
            for: chain,
            connection: engine,
            runtimeProvider: runtimeRegistry
        )

        let partialBuildersOperation = ClosureOperation<PartialBuildersModel> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let genesisHash = try genesisBlockOperation.extractNoCancellableResultData()
            let eraParameters = try eraWrapper.targetOperation.extractNoCancellableResultData()
            let eraBlockHash = try eraBlockOperation.extractNoCancellableResultData()
            let metadataHash = try metadataHashWrapper.targetOperation.extractNoCancellableResultData()

            let mortality = try ExtrinsicMortality(
                eraParameters: eraParameters,
                blockHash: Data(hexString: eraBlockHash)
            )

            let runtimeJsonContext = codingFactory.createRuntimeJsonContext()

            let builders: [ExtrinsicBuilderProtocol] = try indexes.map { index in
                var builder: ExtrinsicBuilderProtocol = ExtrinsicBuilder(
                    extrinsicVersion: extrinsicVersion,
                    specVersion: codingFactory.specVersion,
                    transactionVersion: codingFactory.txVersion,
                    genesisHash: genesisHash
                )
                .with(runtimeJsonContext: runtimeJsonContext)
                .with(era: eraParameters.extrinsicEra, blockHash: eraBlockHash)

                if let metadataHash {
                    builder = builder.with(metadataHash: metadataHash)
                }

                if let defaultTip = chain.defaultTip {
                    builder = builder.with(tip: defaultTip)
                }

                for customExtension in customExtensions {
                    builder = builder.adding(transactionExtension: customExtension)
                }

                return try customClosure(builder, index)
            }

            return PartialBuildersModel(builders: builders, mortality: mortality)
        }

        let dependencies = [genesisBlockOperation] + eraWrapper.allOperations + [eraBlockOperation] +
            metadataHashWrapper.allOperations

        dependencies.forEach { partialBuildersOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: partialBuildersOperation, dependencies: dependencies)
    }

    private func createExtrinsicsOperation(
        dependingOn originResultOperation: BaseOperation<ExtrinsicOriginDefinitionResponse>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        partialBuildersOperation: BaseOperation<PartialBuildersModel>
    ) -> BaseOperation<ExtrinsicsCreationResult> {
        ClosureOperation<ExtrinsicsCreationResult> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let response = try originResultOperation.extractNoCancellableResultData()
            let mortality = try partialBuildersOperation.extractNoCancellableResultData().mortality

            let extrinsics: [Data] = try response.builders.map { builder in
                try builder.build(
                    using: codingFactory,
                    metadata: codingFactory.metadata
                )
            }

            return ExtrinsicsCreationResult(
                extrinsics: extrinsics,
                sender: response.senderResolution,
                mortality: mortality
            )
        }
    }

    override func createExtrinsicWrapper(
        customClosure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetId?,
        purpose: ExtrinsicOriginPurpose,
        indexes: [Int]
    ) -> CompoundOperationWrapper<ExtrinsicsCreationResult> {
        let codingFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()

        let partialBuildersWrapper = createPartialBuildersWrapper(
            customClosure: customClosure,
            indexes: indexes,
            chain: chain,
            extrinsicVersion: extrinsicVersion,
            customExtensions: customExtensions,
            codingFactoryOperation: codingFactoryOperation
        )

        partialBuildersWrapper.addDependency(operations: [codingFactoryOperation])

        let originResolvingWrapper = origin.createOriginResolutionWrapper(
            for: { [feeEstimationRegistry] in
                let builders = try partialBuildersWrapper.targetOperation.extractNoCancellableResultData().builders

                return ExtrinsicOriginDefinitionDependency(
                    builders: builders,
                    senderResolution: .none,
                    feePayment: ExtrinsicFeePaymentDependency(
                        registry: feeEstimationRegistry,
                        feeAssetId: chainAssetId
                    )
                )
            },
            extrinsicVersion: extrinsicVersion,
            purpose: purpose
        )

        originResolvingWrapper.addDependency(wrapper: partialBuildersWrapper)

        let extrinsicOperation = createExtrinsicsOperation(
            dependingOn: originResolvingWrapper.targetOperation,
            codingFactoryOperation: codingFactoryOperation,
            partialBuildersOperation: partialBuildersWrapper.targetOperation
        )

        extrinsicOperation.addDependency(originResolvingWrapper.targetOperation)
        extrinsicOperation.addDependency(codingFactoryOperation)
        extrinsicOperation.addDependency(partialBuildersWrapper.targetOperation)

        return originResolvingWrapper
            .insertingHead(operations: partialBuildersWrapper.allOperations)
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: extrinsicOperation)
    }
}
