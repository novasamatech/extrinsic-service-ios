import Foundation
import SubstrateSdk

import CommonMissing

public enum ExtrinsicSigningContext {
    public struct Substrate {
        public let senderResolution: ExtrinsicSenderResolution
        let extrinsicMemo: ExtrinsicBuilderMemoProtocol
        let codingFactory: RuntimeCoderFactoryProtocol
        
        public init(
            senderResolution: ExtrinsicSenderResolution,
            extrinsicMemo: ExtrinsicBuilderMemoProtocol,
            codingFactory: RuntimeCoderFactoryProtocol
        ) {
            self.senderResolution = senderResolution
            self.extrinsicMemo = extrinsicMemo
            self.codingFactory = codingFactory
        }
    }

    case substrateExtrinsic(Substrate)
    case evmTransaction
    case rawBytes

    public var substrateCryptoType: MultiassetCryptoType? {
        switch self {
        case let .substrateExtrinsic(substrate):
            return substrate.senderResolution.account.cryptoType
        case .evmTransaction, .rawBytes:
            return nil
        }
    }
}
