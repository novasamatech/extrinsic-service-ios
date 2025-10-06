import Foundation
import SubstrateSdk

import CommonMissing

enum ExtrinsicBuilderExtensionError: Error {
    case invalidResolvedAccount
    case invalidRawSignature(data: Data)
}

extension ExtrinsicBuilderProtocol {
    func signing(
        with signingClosure: @escaping (Data, ExtrinsicSigningContext) throws -> Data,
        context: ExtrinsicSigningContext.Substrate,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Self {
        guard let account = context.senderResolution.account else {
            throw ExtrinsicBuilderExtensionError.invalidResolvedAccount
        }

        return switch account.chainFormat {
        case .ethereum:
            try signing(
                by: { data in
                    let signature = try signingClosure(data, .substrateExtrinsic(context))

                    guard let ethereumSignature = EthereumSignature(rawValue: signature) else {
                        throw ExtrinsicBuilderExtensionError.invalidRawSignature(data: signature)
                    }

                    return try ethereumSignature.toScaleCompatibleJSON(
                        with: codingFactory.createRuntimeJsonContext().toRawContext()
                    )
                },
                using: codingFactory,
                metadata: codingFactory.metadata
            )
        case .substrate:
            try signing(
                by: { data in
                    try signingClosure(data, .substrateExtrinsic(context))
                },
                of: account.cryptoType.utilsType,
                using: codingFactory,
                metadata: codingFactory.metadata
            )
        }
    }
}
