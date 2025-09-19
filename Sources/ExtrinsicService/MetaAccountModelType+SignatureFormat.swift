import Foundation
import CommonMissing
import SubstrateSdk

extension MetaAccountModelType {
    var signaturePayloadFormat: ExtrinsicSignaturePayloadFormat {
        switch self {
        case .secrets, .watchOnly, .proxied, .multisig:
            .regular
        case .paritySigner, .polkadotVault:
            .paritySigner
        case .ledger, .genericLedger:
            .extrinsicPayload
        }
    }
}
