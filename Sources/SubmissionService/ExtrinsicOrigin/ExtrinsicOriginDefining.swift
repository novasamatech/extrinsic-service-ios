import Foundation
import Operation_iOS
import SubstrateSdk

public enum ExtrinsicOriginPurpose {
    case feeEstimation
    case submission
}

public struct ExtrinsicOriginDefinitionDependency {
    public let builders: [ExtrinsicBuilderProtocol]
    public let senderResolution: ExtrinsicSenderResolution
}

public struct ExtrinsicOriginDefinitionResponse {
    public let builders: [ExtrinsicBuilderProtocol]
    public let senderResolution: ExtrinsicSenderResolution
}

public protocol ExtrinsicOriginDefining {
    func createOriginResolutionWrapper(
        for dependency: @escaping () throws -> ExtrinsicOriginDefinitionDependency,
        extrinsicVersion: Extrinsic.Version,
        purpose: ExtrinsicOriginPurpose
    ) -> CompoundOperationWrapper<ExtrinsicOriginDefinitionResponse>
}
