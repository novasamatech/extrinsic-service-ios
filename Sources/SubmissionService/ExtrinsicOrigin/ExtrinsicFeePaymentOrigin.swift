import Foundation
import SubstrateSdk
import Operation_iOS

public final class ExtrinsicFeePaymentModifier {
    let runtimeService: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue
    
    public init(
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.runtimeService = runtimeService
        self.operationQueue = operationQueue
    }
}

extension ExtrinsicFeePaymentModifier: ExtrinsicOriginDefining {
    public func createOriginResolutionWrapper(
        for dependency: @escaping () throws -> ExtrinsicOriginDefinitionDependency,
        extrinsicVersion: Extrinsic.Version,
        purpose: ExtrinsicOriginPurpose
    ) -> CompoundOperationWrapper<ExtrinsicOriginDefinitionResponse> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        
        let dependencyOperation = ClosureOperation<ExtrinsicOriginDefinitionDependency> {
            try dependency()
        }
        
        let feeInstallerWrapper = OperationCombiningService<ExtrinsicFeeInstalling>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let dependencyModel = try dependencyOperation.extractNoCancellableResultData()
            
            guard let feePayer = dependencyModel.senderResolution.account else {
                throw ExtrinsicModifierError.noAccountFound
            }
            
            return dependencyModel.feePayment.registry.createFeeInstallerWrapper(
                payingIn: dependencyModel.feePayment.feeAssetId,
                accountClosure: { feePayer }
            )
        }
        
        feeInstallerWrapper.addDependency(operations: [dependencyOperation])
        
        let feeInstallationOperation = ClosureOperation<ExtrinsicOriginDefinitionResponse> {
            let feeInstaller = try feeInstallerWrapper.targetOperation.extractNoCancellableResultData()
            let dependencyModel = try dependencyOperation.extractNoCancellableResultData()
            let coderFactory = try codingFactoryOperation.extractNoCancellableResultData()
            
            let builders = try dependencyModel.builders.map { builder in
                try feeInstaller.installingFeeSettings(
                    to: builder,
                    coderFactory: coderFactory
                )
            }
            
            return ExtrinsicOriginDefinitionResponse(
                builders: builders,
                senderResolution: dependencyModel.senderResolution,
                feePayment: dependencyModel.feePayment
            )
        }
        
        feeInstallationOperation.addDependency(codingFactoryOperation)
        feeInstallationOperation.addDependency(feeInstallerWrapper.targetOperation)
        
        return feeInstallerWrapper
            .insertingHead(operations: [dependencyOperation])
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: feeInstallationOperation)
    }
}
