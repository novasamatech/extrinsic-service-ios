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
    ) -> CompoundOperationWrapper<[ExtrinsicBuilderProtocol]> {
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

        let partialBuildersOperation = ClosureOperation<[ExtrinsicBuilderProtocol]> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let genesisHash = try genesisBlockOperation.extractNoCancellableResultData()
            let era = try eraWrapper.targetOperation.extractNoCancellableResultData().extrinsicEra
            let eraBlockHash = try eraBlockOperation.extractNoCancellableResultData()
            let metadataHash = try metadataHashWrapper.targetOperation.extractNoCancellableResultData()

            let runtimeJsonContext = codingFactory.createRuntimeJsonContext()

            return try indexes.map { index in
                var builder: ExtrinsicBuilderProtocol = ExtrinsicBuilder(
                    extrinsicVersion: extrinsicVersion,
                    specVersion: codingFactory.specVersion,
                    transactionVersion: codingFactory.txVersion,
                    genesisHash: genesisHash
                )
                .with(runtimeJsonContext: runtimeJsonContext)
                .with(era: era, blockHash: eraBlockHash)

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
        }

        let dependencies = [genesisBlockOperation] + eraWrapper.allOperations + [eraBlockOperation] +
            metadataHashWrapper.allOperations

        dependencies.forEach { partialBuildersOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: partialBuildersOperation, dependencies: dependencies)
    }

    private func createExtrinsicsOperation(
        dependingOn originResultOperation: BaseOperation<ExtrinsicOriginDefinitionResponse>,
        feeInstallerOperation: BaseOperation<ExtrinsicFeeInstalling>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<ExtrinsicsCreationResult> {
        ClosureOperation<ExtrinsicsCreationResult> {
            let feeInstaller = try feeInstallerOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let response = try originResultOperation.extractNoCancellableResultData()

            let extrinsics: [Data] = try response.builders.map { builder in
                try feeInstaller.installingFeeSettings(
                    to: builder,
                    coderFactory: codingFactory
                ).build(
                    using: codingFactory,
                    metadata: codingFactory.metadata
                )
            }

            return (extrinsics, response.senderResolution)
        }
    }

    override func createExtrinsicWrapper(
        customClosure: @escaping ExtrinsicBuilderIndexedClosure,
        origin: ExtrinsicOriginDefining,
        payingIn chainAssetId: ChainAssetIdProtocol?,
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
            for: {
                let builders = try partialBuildersWrapper.targetOperation.extractNoCancellableResultData()

                return ExtrinsicOriginDefinitionDependency(builders: builders, senderResolution: .none)
            },
            extrinsicVersion: extrinsicVersion,
            purpose: purpose
        )

        originResolvingWrapper.addDependency(wrapper: partialBuildersWrapper)
        
        let feeInstallerWrapper = feeEstimationRegistry.createFeeInstallerWrapper(payingIn: chainAssetId) {
            let resolver = try originResolvingWrapper.targetOperation.extractNoCancellableResultData()
            
            guard let account = resolver.senderResolution.account else {
                throw ExtrinsicOperationFactoryError.missingSender
            }
            
            return account
        }

        feeInstallerWrapper.addDependency(wrapper: originResolvingWrapper)

        let extrinsicOperation = createExtrinsicsOperation(
            dependingOn: originResolvingWrapper.targetOperation,
            feeInstallerOperation: feeInstallerWrapper.targetOperation,
            codingFactoryOperation: codingFactoryOperation
        )

        extrinsicOperation.addDependency(originResolvingWrapper.targetOperation)
        extrinsicOperation.addDependency(feeInstallerWrapper.targetOperation)
        extrinsicOperation.addDependency(codingFactoryOperation)

        return feeInstallerWrapper
            .insertingHead(operations: originResolvingWrapper.allOperations)
            .insertingHead(operations: partialBuildersWrapper.allOperations)
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: extrinsicOperation)
    }
}
