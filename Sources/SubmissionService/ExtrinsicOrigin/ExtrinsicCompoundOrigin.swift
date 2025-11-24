import Foundation
import Operation_iOS
import SubstrateSdk

public final class ExtrinsicCompoundOrigin {
    let children: [ExtrinsicOriginDefining]

    public init(children: [ExtrinsicOriginDefining]) {
        self.children = children
    }
}

extension ExtrinsicCompoundOrigin: ExtrinsicOriginDefining {
    public func createOriginResolutionWrapper(
        for dependency: @escaping () throws -> ExtrinsicOriginDefinitionDependency,
        extrinsicVersion: Extrinsic.Version,
        purpose: ExtrinsicOriginPurpose
    ) -> CompoundOperationWrapper<ExtrinsicOriginDefinitionResponse> {
        let initWrapper = CompoundOperationWrapper(targetOperation: ClosureOperation {
            let dep = try dependency()

            return ExtrinsicOriginDefinitionResponse(
                builders: dep.builders,
                senderResolution: dep.senderResolution,
                feePayment: dep.feePayment
            )
        })

        return children.reduce(initWrapper) { accumWrapper, child in
            let childWrapper = child.createOriginResolutionWrapper(
                for: {
                    let response = try accumWrapper.targetOperation.extractNoCancellableResultData()

                    return ExtrinsicOriginDefinitionDependency(
                        builders: response.builders,
                        senderResolution: response.senderResolution,
                        feePayment: response.feePayment
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
