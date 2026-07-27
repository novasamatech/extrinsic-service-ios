import Foundation
import Operation_iOS
import SubstrateSdk
@testable import ExtrinsicService

final class ExtrinsicOperationFactoryMock: ExtrinsicOperationFactoryProtocol {
    let connection: JSONRPCEngine

    var buildExtrinsicResult: Result<ExtrinsicBuiltModel, Error>
    var buildExtrinsicsResult: Result<[ExtrinsicBuiltModel], Error>

    private let lock = NSLock()
    private var storedRequestedIndexes: [IndexSet] = []

    var requestedIndexes: [IndexSet] {
        lock.withLock { storedRequestedIndexes }
    }

    init(
        connection: JSONRPCEngine = JSONRPCEngineMock(),
        buildExtrinsicResult: Result<ExtrinsicBuiltModel, Error> = .success(.stub("0x01")),
        buildExtrinsicsResult: Result<[ExtrinsicBuiltModel], Error> = .success([])
    ) {
        self.connection = connection
        self.buildExtrinsicResult = buildExtrinsicResult
        self.buildExtrinsicsResult = buildExtrinsicsResult
    }

    func buildExtrinsic(
        _: @escaping ExtrinsicBuilderClosure,
        origin _: ExtrinsicOriginDefining,
        payingIn _: ChainAssetId?
    ) -> CompoundOperationWrapper<ExtrinsicBuiltModel> {
        let result = buildExtrinsicResult

        return CompoundOperationWrapper(targetOperation: ClosureOperation { try result.get() })
    }

    func buildExtrinsics(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        origin _: ExtrinsicOriginDefining,
        payingIn _: ChainAssetId?,
        indexes: IndexSet
    ) -> CompoundOperationWrapper<[ExtrinsicBuiltModel]> {
        lock.withLock { storedRequestedIndexes.append(indexes) }

        let result = buildExtrinsicsResult

        return CompoundOperationWrapper(targetOperation: ClosureOperation { try result.get() })
    }

    func estimateFeeOperation(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        origin _: ExtrinsicOriginDefining,
        payingIn _: ChainAssetId?,
        indexes _: IndexSet
    ) -> CompoundOperationWrapper<FeeIndexedExtrinsicResult> {
        fatalError("unused in tests")
    }

    func submit(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        origin _: ExtrinsicOriginDefining,
        payingIn _: ChainAssetId?,
        indexes _: IndexSet
    ) -> CompoundOperationWrapper<SubmitIndexedExtrinsicResult> {
        fatalError("the service must submit through ExtrinsicSubmitting, not the factory")
    }
}

extension ExtrinsicBuiltModel {
    static func stub(_ extrinsic: String) -> ExtrinsicBuiltModel {
        ExtrinsicBuiltModel(extrinsic: extrinsic, sender: .none)
    }
}
