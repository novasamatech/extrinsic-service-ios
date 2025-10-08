import Foundation
import Operation_iOS
import SubstrateSdk

final class ExtrinsicCompoundOrigin {
    let children: [ExtrinsicOriginDefining]

    init(children: [ExtrinsicOriginDefining]) {
        self.children = children
    }
}

extension ExtrinsicCompoundOrigin: ExtrinsicOriginDefining {
    func createOriginResolutionWrapper(
        for dependency: @escaping () throws -> ExtrinsicOriginDefinitionDependency,
        extrinsicVersion: Extrinsic.Version,
        purpose: ExtrinsicOriginPurpose
    ) -> CompoundOperationWrapper<ExtrinsicOriginDefinitionResponse> {
        let initWrapper = CompoundOperationWrapper(targetOperation: ClosureOperation {
            let dep = try dependency()

            return ExtrinsicOriginDefinitionResponse(
                builders: dep.builders,
                senderResolution: dep.senderResolution
            )
        })

        return children.reduce(initWrapper) { accumWrapper, child in
            let childWrapper = child.createOriginResolutionWrapper(
                for: {
                    let response = try accumWrapper.targetOperation.extractNoCancellableResultData()

                    return ExtrinsicOriginDefinitionDependency(
                        builders: response.builders,
                        senderResolution: response.senderResolution
                    )

                },
                extrinsicVersion: extrinsicVersion,
                purpose: purpose
            )

            childWrapper.addDependency(wrapper: accumWrapper)

            return childWrapper.insertingHead(operations: accumWrapper.allOperations)
        }
    }
}
