import Foundation

public struct ExtrinsicFeeEstimationResult: ExtrinsicFeeEstimationResultProtocol {
    public let items: [ExtrinsicFeeProtocol]
    
    public init(items: [ExtrinsicFeeProtocol]) {
        self.items = items
    }
}
