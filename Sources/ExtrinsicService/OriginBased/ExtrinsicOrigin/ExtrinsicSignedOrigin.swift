import Foundation
import Operation_iOS
import SubstrateSdk
import CommonMissing

enum ExtrinsicSignedOriginError: Error {
    case noSigningAccountFound
}

final class ExtrinsicSignedOrigin {
    let runtimeProvider: RuntimeCodingServiceProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol

    init(
        runtimeProvider: RuntimeCodingServiceProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol
    ) {
        self.runtimeProvider = runtimeProvider
        self.signingWrapperFactory = signingWrapperFactory
    }
}

private extension ExtrinsicSignedOrigin {
    func createBuildersUpdate(
        dependingOn dependencyOperation: BaseOperation<ExtrinsicOriginDefinitionDependency>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        signerOperation: BaseOperation<SigningWrapperProtocol>,
        extrinsicVersion _: Extrinsic.Version
    ) -> BaseOperation<ExtrinsicOriginDefinitionResponse> {
        ClosureOperation<ExtrinsicOriginDefinitionResponse> {
            let dependencies = try dependencyOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let signer = try signerOperation.extractNoCancellableResultData()

            let builders = dependencies.builders
            let senderResolution = dependencies.senderResolution

            let resultBuilders: [ExtrinsicBuilderProtocol] = try builders.map { partialBuilder in
                guard let account = senderResolution.account else {
                    throw ExtrinsicSignedOriginError.noSigningAccountFound
                }

                let builder = partialBuilder.with(
                    signaturePayloadFormat: account.type.signaturePayloadFormat
                )

                let context = ExtrinsicSigningContext.Substrate(
                    senderResolution: dependencies.senderResolution,
                    extrinsicMemo: builder.makeMemo(),
                    codingFactory: codingFactory
                )

                return try builder.signing(
                    with: { data, context in
                        try signer.sign(data, context: context).rawData()
                    },
                    context: context,
                    codingFactory: codingFactory
                )
            }

            return ExtrinsicOriginDefinitionResponse(
                builders: resultBuilders,
                senderResolution: senderResolution
            )
        }
    }

    func createSignerOperation(
        dependingOn dependencyOperation: BaseOperation<ExtrinsicOriginDefinitionDependency>,
        purpose: ExtrinsicOriginPurpose,
        signingWrapperFactory: SigningWrapperFactoryProtocol
    ) -> BaseOperation<SigningWrapperProtocol> {
        ClosureOperation<SigningWrapperProtocol> {
            let dependencies = try dependencyOperation.extractNoCancellableResultData()

            guard let account = dependencies.senderResolution.account else {
                throw ExtrinsicSignedOriginError.noSigningAccountFound
            }

            switch purpose {
            case .feeEstimation:
                return try DummySigner(cryptoType: account.cryptoType)
            case .submission:
                return signingWrapperFactory.createSigningWrapper(
                    for: account.metaId,
                    accountResponse: account
                )
            }
        }
    }
}

extension ExtrinsicSignedOrigin: ExtrinsicOriginDefining {
    func createOriginResolutionWrapper(
        for dependency: @escaping () throws -> ExtrinsicOriginDefinitionDependency,
        extrinsicVersion: Extrinsic.Version,
        purpose: ExtrinsicOriginPurpose
    ) -> CompoundOperationWrapper<ExtrinsicOriginDefinitionResponse> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let dependenciesOperation = ClosureOperation<ExtrinsicOriginDefinitionDependency> {
            try dependency()
        }

        let signerOperation = createSignerOperation(
            dependingOn: dependenciesOperation,
            purpose: purpose,
            signingWrapperFactory: signingWrapperFactory
        )

        signerOperation.addDependency(dependenciesOperation)

        let buildersUpdateOperation = createBuildersUpdate(
            dependingOn: dependenciesOperation,
            codingFactoryOperation: codingFactoryOperation,
            signerOperation: signerOperation,
            extrinsicVersion: extrinsicVersion
        )

        buildersUpdateOperation.addDependency(codingFactoryOperation)
        buildersUpdateOperation.addDependency(dependenciesOperation)
        buildersUpdateOperation.addDependency(signerOperation)

        return CompoundOperationWrapper(
            targetOperation: buildersUpdateOperation,
            dependencies: [codingFactoryOperation, dependenciesOperation, signerOperation]
        )
    }
}
