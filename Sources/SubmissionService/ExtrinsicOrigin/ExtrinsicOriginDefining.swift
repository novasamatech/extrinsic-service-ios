import Foundation
import Operation_iOS
import SubstrateSdk

public enum ExtrinsicOriginPurpose {
    case feeEstimation
    case submission
}

public struct ExtrinsicOriginDefinitionDependency {
    let builders: [ExtrinsicBuilderProtocol]
    let senderResolution: ExtrinsicSenderResolution
}

public struct ExtrinsicOriginDefinitionResponse {
    let builders: [ExtrinsicBuilderProtocol]
    let senderResolution: ExtrinsicSenderResolution
}

public protocol ExtrinsicOriginDefining {
    func createOriginResolutionWrapper(
        for dependency: @escaping () throws -> ExtrinsicOriginDefinitionDependency,
        extrinsicVersion: Extrinsic.Version,
        purpose: ExtrinsicOriginPurpose
    ) -> CompoundOperationWrapper<ExtrinsicOriginDefinitionResponse>
}
