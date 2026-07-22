import Foundation
import Operation_iOS
import SubstrateSdk
@testable import ExtrinsicService

final class ExtrinsicOriginDefiningMock: ExtrinsicOriginDefining {
    func createOriginResolutionWrapper(
        for _: @escaping () throws -> ExtrinsicOriginDefinitionDependency,
        extrinsicVersion _: Extrinsic.Version,
        purpose _: ExtrinsicOriginPurpose
    ) -> CompoundOperationWrapper<ExtrinsicOriginDefinitionResponse> {
        fatalError("unused in tests")
    }
}
