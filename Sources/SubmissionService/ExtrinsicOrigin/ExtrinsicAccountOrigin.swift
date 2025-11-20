import Foundation
import SubstrateSdk
import Operation_iOS

public final class ExtrinsicAccountOrigin {
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let senderResolvingFactory: ExtrinsicSenderResolutionFactoryProtocol
    let nonceOperationFactory: NonceOperationFactoryProtocol

    public init(
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
        partialResponseOperation: BaseOperation<ExtrinsicOriginDefinitionResponse>,
        extrinsicVersion: Extrinsic.Version
    ) -> BaseOperation<ExtrinsicOriginDefinitionResponse> {
        ClosureOperation<ExtrinsicOriginDefinitionResponse> {
            let nonce = try nonceOperation.extractNoCancellableResultData()
            let partialResponse = try partialResponseOperation.extractNoCancellableResultData()

            let builders = partialResponse.builders
            let resultBuilders: [ExtrinsicBuilderProtocol] = try builders.enumerated().map { index, partialBuilder in
                var builder = partialBuilder.with(nonce: nonce + UInt32(index))

                guard let account = partialResponse.senderResolution.account else {
                    throw ExtrinsicModifierError.noAccountFound
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
                senderResolution: partialResponse.senderResolution,
                feePayment: partialResponse.feePayment
            )
        }
    }
}

extension ExtrinsicAccountOrigin: ExtrinsicOriginDefining {
    public func createOriginResolutionWrapper(
        for dependency: @escaping () throws -> ExtrinsicOriginDefinitionDependency,
        extrinsicVersion: Extrinsic.Version,
        purpose _: ExtrinsicOriginPurpose
    ) -> CompoundOperationWrapper<ExtrinsicOriginDefinitionResponse> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let senderResolverWrapper = senderResolvingFactory.createWrapper()

        let dependenciesOperation = ClosureOperation<ExtrinsicOriginDefinitionDependency> {
            try dependency()
        }

        let partialResponseOperation = ClosureOperation<ExtrinsicOriginDefinitionResponse> {
            let dependencyModel = try dependenciesOperation.extractNoCancellableResultData()
            let builders = dependencyModel.builders
            let resolver = try senderResolverWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let (senderResolution, newBuilders) = try resolver.resolveSender(
                wrapping: builders,
                codingFactory: codingFactory
            )
            
            return ExtrinsicOriginDefinitionResponse(
                builders: newBuilders,
                senderResolution: senderResolution,
                feePayment: dependencyModel.feePayment
            )
        }

        partialResponseOperation.addDependency(codingFactoryOperation)
        partialResponseOperation.addDependency(senderResolverWrapper.targetOperation)
        partialResponseOperation.addDependency(dependenciesOperation)

        let nonceWrapper = nonceOperationFactory.createWrapper {
            let partialResponse = try partialResponseOperation.extractNoCancellableResultData()

            guard let account = partialResponse.senderResolution.account else {
                throw ExtrinsicModifierError.noAccountFound
            }

            return account.accountId
        }

        nonceWrapper.addDependency(operations: [partialResponseOperation])

        let buildersUpdateOperation = createBuildersUpdate(
            dependingOn: nonceWrapper.targetOperation,
            partialResponseOperation: partialResponseOperation,
            extrinsicVersion: extrinsicVersion
        )

        buildersUpdateOperation.addDependency(nonceWrapper.targetOperation)
        buildersUpdateOperation.addDependency(partialResponseOperation)

        return nonceWrapper
            .insertingHead(operations: [dependenciesOperation, partialResponseOperation])
            .insertingHead(operations: senderResolverWrapper.allOperations)
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: buildersUpdateOperation)
    }
}
