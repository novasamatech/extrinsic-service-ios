import Foundation
import SubstrateSdk
import Operation_iOS
import CommonMissing

final class ExtrinsicAccountOrigin {
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let senderResolvingFactory: ExtrinsicSenderResolutionFactoryProtocol
    let nonceOperationFactory: NonceOperationFactoryProtocol

    init(
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        senderResolvingFactory: ExtrinsicSenderResolutionFactoryProtocol,
        nonceOperationFactory: NonceOperationFactoryProtocol
    ) {
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.senderResolvingFactory = senderResolvingFactory
        self.nonceOperationFactory = nonceOperationFactory
    }
}

private extension ExtrinsicAccountOrigin {
    func createBuildersUpdate(
        dependingOn nonceOperation: BaseOperation<UInt32>,
        senderResolutionOperation: BaseOperation<ExtrinsicSenderBuilderResolution>,
        extrinsicVersion: Extrinsic.Version
    ) -> BaseOperation<ExtrinsicOriginDefinitionResponse> {
        ClosureOperation<ExtrinsicOriginDefinitionResponse> {
            let nonce = try nonceOperation.extractNoCancellableResultData()
            let (senderResolution, builders) = try senderResolutionOperation.extractNoCancellableResultData()

            let resultBuilders: [ExtrinsicBuilderProtocol] = try builders.enumerated().map { index, partialBuilder in
                var builder = partialBuilder.with(nonce: nonce + UInt32(index))

                guard let account = senderResolution.account else {
                    throw ExtrinsicSignedOriginError.noSigningAccountFound
                }

                switch extrinsicVersion {
                case .V4:
                    builder = try builder.with(address: MultiAddress.accoundId(account.accountId))
                case .V5:
                    builder = try builder.with(address: BytesCodable(wrappedValue: account.accountId))
                }

                return builder
            }

            return ExtrinsicOriginDefinitionResponse(
                builders: resultBuilders,
                senderResolution: senderResolution
            )
        }
    }
}

extension ExtrinsicAccountOrigin: ExtrinsicOriginDefining {
    func createOriginResolutionWrapper(
        for dependency: @escaping () throws -> ExtrinsicOriginDefinitionDependency,
        extrinsicVersion: Extrinsic.Version,
        purpose _: ExtrinsicOriginPurpose
    ) -> CompoundOperationWrapper<ExtrinsicOriginDefinitionResponse> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let senderResolverWrapper = senderResolvingFactory.createWrapper()

        let dependenciesOperation = ClosureOperation<ExtrinsicOriginDefinitionDependency> {
            try dependency()
        }

        let senderResolutionOperation = ClosureOperation<ExtrinsicSenderBuilderResolution> {
            let builders = try dependenciesOperation.extractNoCancellableResultData().builders
            let resolver = try senderResolverWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            return try resolver.resolveSender(wrapping: builders, codingFactory: codingFactory)
        }

        senderResolutionOperation.addDependency(codingFactoryOperation)
        senderResolutionOperation.addDependency(senderResolverWrapper.targetOperation)
        senderResolutionOperation.addDependency(dependenciesOperation)

        let nonceWrapper = nonceOperationFactory.createWrapper {
            let (senderResolution, _) = try senderResolutionOperation.extractNoCancellableResultData()

            guard let account = senderResolution.account else {
                throw ExtrinsicSignedOriginError.noSigningAccountFound
            }

            return account.accountId
        }

        nonceWrapper.addDependency(operations: [senderResolutionOperation])

        let buildersUpdateOperation = createBuildersUpdate(
            dependingOn: nonceWrapper.targetOperation,
            senderResolutionOperation: senderResolutionOperation,
            extrinsicVersion: extrinsicVersion
        )

        buildersUpdateOperation.addDependency(nonceWrapper.targetOperation)
        buildersUpdateOperation.addDependency(senderResolutionOperation)

        return nonceWrapper
            .insertingHead(operations: [dependenciesOperation, senderResolutionOperation])
            .insertingHead(operations: senderResolverWrapper.allOperations)
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: buildersUpdateOperation)
    }
}
