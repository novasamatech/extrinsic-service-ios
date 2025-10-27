import Foundation
import SubstrateSdk

public final class ExtrinsicNativeFeeInstaller {
    public init() {}
}

extension ExtrinsicNativeFeeInstaller: ExtrinsicFeeInstalling {
    public func installingFeeSettings(
        to builder: ExtrinsicBuilderProtocol,
        coderFactory _: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        builder
    }
}
