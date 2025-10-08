import Foundation
import SubstrateSdk

public struct ExtrinsicRetriableResult<R> {
    struct IndexedResult {
        let index: Int
        let result: Result<R, Error>
    }

    let builderClosure: ExtrinsicBuilderIndexedClosure?
    let results: [IndexedResult]

    init(
        builderClosure: ExtrinsicBuilderIndexedClosure?,
        results: [IndexedResult]
    ) {
        self.builderClosure = builderClosure
        self.results = results
    }

    init(
        builderClosure: ExtrinsicBuilderIndexedClosure?,
        error: Error,
        indexes: [Int]
    ) {
        self.builderClosure = builderClosure
        results = indexes.map { .init(index: $0, result: .failure(error)) }
    }

    func failedIndexes() -> IndexSet {
        let indexList: [Int] = results.compactMap { indexedResult in
            switch indexedResult.result {
            case .success:
                return nil
            case .failure:
                return indexedResult.index
            }
        }

        return IndexSet(indexList)
    }

    func errors() -> [Error] {
        let errors: [Error] = results.compactMap { indexedResult in
            switch indexedResult.result {
            case .success:
                return nil
            case let .failure(error):
                return error
            }
        }

        return errors
    }
}

extension ExtrinsicRetriableResult where R == ExtrinsicSubmittedModel {
    func senders() -> [ExtrinsicSenderResolution] {
        let senders: [ExtrinsicSenderResolution] = results.compactMap { indexedResult in
            switch indexedResult.result {
            case let .success(model):
                return model.sender
            case .failure:
                return nil
            }
        }

        return senders
    }
}

public struct ExtrinsicSubmittedModel {
    let txHash: String
    let sender: ExtrinsicSenderResolution
}

struct ExtrinsicSubscribedStatusModel {
    let statusUpdate: ExtrinsicStatusUpdate
    let sender: ExtrinsicSenderResolution

    var extrinsicSubmittedModel: ExtrinsicSubmittedModel {
        ExtrinsicSubmittedModel(
            txHash: statusUpdate.extrinsicHash,
            sender: sender
        )
    }
}

public struct ExtrinsicBuiltModel {
    let extrinsic: String
    let sender: ExtrinsicSenderResolution
}

typealias FeeExtrinsicResult = Result<ExtrinsicFeeProtocol, Error>
public typealias FeeIndexedExtrinsicResult = ExtrinsicRetriableResult<ExtrinsicFeeProtocol>

typealias EstimateFeeClosure = (FeeExtrinsicResult) -> Void
typealias EstimateFeeIndexedClosure = (FeeIndexedExtrinsicResult) -> Void

typealias SubmitExtrinsicResult = Result<ExtrinsicSubmittedModel, Error>
public typealias SubmitIndexedExtrinsicResult = ExtrinsicRetriableResult<ExtrinsicSubmittedModel>

typealias ExtrinsicSubmitClosure = (SubmitExtrinsicResult) -> Void
typealias ExtrinsicSubmitIndexedClosure = (SubmitIndexedExtrinsicResult) -> Void

typealias ExtrinsicBuiltResult = Result<ExtrinsicBuiltModel, Error>
typealias ExtrinsicBuiltClosure = (ExtrinsicBuiltResult) -> Void

typealias ExtrinsicSubscriptionIdClosure = (UInt16) -> Bool
typealias ExtrinsicSubscriptionStatusClosure = (Result<ExtrinsicSubscribedStatusModel, Error>) -> Void

public typealias ExtrinsicBuilderClosure = (ExtrinsicBuilderProtocol) throws -> (ExtrinsicBuilderProtocol)
public typealias ExtrinsicBuilderIndexedClosure = (ExtrinsicBuilderProtocol, Int) throws -> (ExtrinsicBuilderProtocol)

public typealias ExtrinsicsCreationResult = (extrinsics: [Data], sender: ExtrinsicSenderResolution)

typealias ExtrinsicSubscriptionUpdate = JSONRPCSubscriptionUpdate<ExtrinsicStatus>
