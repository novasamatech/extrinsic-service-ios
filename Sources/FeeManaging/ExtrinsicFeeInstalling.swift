import Foundation
import SubstrateSdk

public protocol ExtrinsicFeeInstalling {
    func installingFeeSettings(
        to builder: ExtrinsicBuilderProtocol,
        coderFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicBuilderProtocol
}
