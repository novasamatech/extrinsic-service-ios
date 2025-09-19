import Foundation
import SubstrateSdk
import CommonMissing

final class ExtrinsicNativeFeeInstaller {}

extension ExtrinsicNativeFeeInstaller: ExtrinsicFeeInstalling {
    func installingFeeSettings(
        to builder: ExtrinsicBuilderProtocol,
        coderFactory _: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        builder
    }
}
