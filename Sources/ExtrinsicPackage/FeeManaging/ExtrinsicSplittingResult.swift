import Foundation
import Operation_iOS
import SubstrateSdk

public struct ExtrinsicSplittingResult {
    let closure: ExtrinsicBuilderIndexedClosure
    let numberOfExtrinsics: Int
}

public protocol ExtrinsicSplitting: AnyObject {
    func adding<T: RuntimeCallable>(call: T) -> Self

    func buildWrapper(
        using operationFactory: ExtrinsicOperationFactoryProtocol
    ) -> CompoundOperationWrapper<ExtrinsicSplittingResult>
}
