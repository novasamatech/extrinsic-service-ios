import Foundation
import Operation_iOS
import SubstrateSdk

public enum ExtrinsicOriginPurpose {
    case feeEstimation
    case submission
}

public struct ExtrinsicFeePaymentDependency {
    public let registry: ExtrinsicFeeEstimationRegistring
    public let feeAssetId: ChainAssetId?
}

public struct ExtrinsicOriginDefinitionDependency {
    public let builders: [ExtrinsicBuilderProtocol]
    public let senderResolution: ExtrinsicSenderResolution
    public let feePayment: ExtrinsicFeePaymentDependency
    
    public init(
        builders: [ExtrinsicBuilderProtocol],
        senderResolution: ExtrinsicSenderResolution,
        feePayment: ExtrinsicFeePaymentDependency
    ) {
        self.builders = builders
        self.senderResolution = senderResolution
        self.feePayment = feePayment
    }
}

public struct ExtrinsicOriginDefinitionResponse {
    public let builders: [ExtrinsicBuilderProtocol]
    public let senderResolution: ExtrinsicSenderResolution
    public let feePayment: ExtrinsicFeePaymentDependency
    
    public init(
        builders: [ExtrinsicBuilderProtocol],
        senderResolution: ExtrinsicSenderResolution,
        feePayment: ExtrinsicFeePaymentDependency
    ) {
        self.builders = builders
        self.senderResolution = senderResolution
        self.feePayment = feePayment
    }
}

public protocol ExtrinsicOriginDefining {
    func createOriginResolutionWrapper(
        for dependency: @escaping () throws -> ExtrinsicOriginDefinitionDependency,
        extrinsicVersion: Extrinsic.Version,
        purpose: ExtrinsicOriginPurpose
    ) -> CompoundOperationWrapper<ExtrinsicOriginDefinitionResponse>
}
