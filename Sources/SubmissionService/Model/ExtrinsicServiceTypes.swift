import Foundation
import SubstrateSdk

public struct ExtrinsicRetriableResult<R> {
    public struct IndexedResult {
        let index: Int
        let result: Result<R, Error>
    }

    public let builderClosure: ExtrinsicBuilderIndexedClosure?
    public let results: [IndexedResult]

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

    public func failedIndexes() -> IndexSet {
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

    public func errors() -> [Error] {
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

public extension ExtrinsicRetriableResult where R == ExtrinsicSubmittedModel {
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
    public let txHash: String
    public let sender: ExtrinsicSenderResolution
}

public struct ExtrinsicSubscribedStatusModel {
    public let statusUpdate: ExtrinsicStatusUpdate
    public let sender: ExtrinsicSenderResolution

    public var extrinsicSubmittedModel: ExtrinsicSubmittedModel {
        ExtrinsicSubmittedModel(
            txHash: statusUpdate.extrinsicHash,
            sender: sender
        )
    }
}

public struct ExtrinsicBuiltModel {
    public let extrinsic: String
    public let sender: ExtrinsicSenderResolution
}

public typealias FeeExtrinsicResult = Result<ExtrinsicFeeProtocol, Error>
public typealias FeeIndexedExtrinsicResult = ExtrinsicRetriableResult<ExtrinsicFeeProtocol>

public typealias EstimateFeeClosure = (FeeExtrinsicResult) -> Void
public typealias EstimateFeeIndexedClosure = (FeeIndexedExtrinsicResult) -> Void

public typealias SubmitExtrinsicResult = Result<ExtrinsicSubmittedModel, Error>
public typealias SubmitIndexedExtrinsicResult = ExtrinsicRetriableResult<ExtrinsicSubmittedModel>

public typealias ExtrinsicSubmitClosure = (SubmitExtrinsicResult) -> Void
public typealias ExtrinsicSubmitIndexedClosure = (SubmitIndexedExtrinsicResult) -> Void

public typealias ExtrinsicBuiltResult = Result<ExtrinsicBuiltModel, Error>
public typealias ExtrinsicBuiltClosure = (ExtrinsicBuiltResult) -> Void

public typealias ExtrinsicSubscriptionIdClosure = (UInt16) -> Bool
public typealias ExtrinsicSubscriptionStatusClosure = (Result<ExtrinsicSubscribedStatusModel, Error>) -> Void

public typealias ExtrinsicBuilderClosure = (ExtrinsicBuilderProtocol) throws -> (ExtrinsicBuilderProtocol)
public typealias ExtrinsicBuilderIndexedClosure = (ExtrinsicBuilderProtocol, Int) throws -> (ExtrinsicBuilderProtocol)

public typealias ExtrinsicsCreationResult = (extrinsics: [Data], sender: ExtrinsicSenderResolution)

public typealias ExtrinsicSubscriptionUpdate = JSONRPCSubscriptionUpdate<ExtrinsicStatus>
