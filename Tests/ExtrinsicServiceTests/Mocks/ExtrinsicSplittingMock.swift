import Foundation
import Operation_iOS
import SubstrateSdk
@testable import ExtrinsicService

final class ExtrinsicSplittingMock: ExtrinsicSplitting {
    var numberOfExtrinsics: Int

    init(numberOfExtrinsics: Int) {
        self.numberOfExtrinsics = numberOfExtrinsics
    }

    func adding<T: RuntimeCallable>(call _: T) -> Self {
        self
    }

    func buildWrapper(
        using _: ExtrinsicOperationFactoryProtocol,
        origin _: ExtrinsicOriginDefining
    ) -> CompoundOperationWrapper<ExtrinsicSplittingResult> {
        let result = ExtrinsicSplittingResult(
            closure: { builder, _ in builder },
            numberOfExtrinsics: numberOfExtrinsics
        )

        return CompoundOperationWrapper(targetOperation: ClosureOperation { result })
    }
}
