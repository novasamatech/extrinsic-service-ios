import Testing
import Foundation
@testable import ExtrinsicService

@Suite("ExtrinsicService routing")
struct ExtrinsicServiceRoutingTests {
    @Test("submitAndWatch hands the built extrinsic to the submitter on the caller's queue")
    func submitAndWatchForwardsToSubmitter() throws {
        let context = Context(buildExtrinsic: .success(.stub("0xaa")))

        context.submitAndWatch()

        try context.submitter.subscribed.wait()
        let call = try #require(context.submitter.subscribeCalls.first)
        #expect(call.builtExtrinsic.extrinsic == "0xaa")
        #expect(call.queue === context.queue)
    }

    @Test("a build failure is reported without reaching the submitter")
    func buildFailureSkipsSubmitter() throws {
        let context = Context(buildExtrinsic: .failure(TestError.build))
        let notified = AsyncExpectation()
        let statuses = Recorded<Result<ExtrinsicSubscribedStatusModel, Error>>()

        context.submitAndWatch { result in
            statuses.record(result)
            notified.fulfill()
        }

        try notified.wait()
        #expect(context.submitter.subscribeCalls.isEmpty, "a doomed build must never reach the submitter")
        guard case .failure = try #require(statuses.first) else {
            Issue.record("expected a failure notification")
            return
        }
    }

    @Test("indexed submitAndWatch subscribes once per index and tags notifications")
    func indexedSubmitAndWatchTagsIndexes() throws {
        let context = Context(buildExtrinsics: .success([.stub("0xaa"), .stub("0xbb")]))
        let notified = AsyncExpectation()
        let tagged = Recorded<Int>()

        context.service.submitAndWatch(
            { builder, _ in builder },
            origin: ExtrinsicOriginDefiningMock(),
            payingIn: nil,
            runningIn: context.queue,
            indexes: IndexSet([2, 5]),
            subscriptionIdClosure: { _, _ in true },
            notificationClosure: { index, _ in
                tagged.record(index)
                notified.fulfill()
            }
        )

        try context.submitter.subscribed.wait(count: 2)
        #expect(context.submitter.subscribeCalls.count == 2)

        context.submitter.subscribeCalls[0].notificationClosure(.failure(TestError.submission))
        context.submitter.subscribeCalls[1].notificationClosure(.failure(TestError.submission))

        try notified.wait(count: 2)
        #expect(tagged.values == [2, 5], "notifications must carry the original index values")
    }

    @Test("cancelExtrinsicWatch delegates to the submitter, not the connection")
    func cancelDelegatesToSubmitter() {
        let context = Context()

        context.service.cancelExtrinsicWatch(for: 99)

        #expect(
            context.submitter.cancelledIds == [99],
            "a custom submitter owns its handles — bypassing it silently breaks cancellation"
        )
    }
}

// MARK: - Submit paths

extension ExtrinsicServiceRoutingTests {
    @Test("submit routes a single built extrinsic through the submitter")
    func submitRoutesSingleExtrinsic() throws {
        let context = Context(buildExtrinsic: .success(.stub("0xaa")))
        let completed = AsyncExpectation()
        let results = Recorded<SubmitExtrinsicResult>()

        context.service.submit(
            { $0 },
            origin: ExtrinsicOriginDefiningMock(),
            payingIn: nil,
            runningIn: context.queue
        ) { result in
            results.record(result)
            completed.fulfill()
        }

        try completed.wait()
        #expect(context.submitter.submitCalls.first?.count == 1)
        let submitted = try #require(results.first).get()
        #expect(submitted.txHash == "0xaa")
    }

    @Test("a non-contiguous IndexSet keeps results keyed to the original indexes")
    func nonContiguousIndexesArePreserved() throws {
        let context = Context(buildExtrinsics: .success([.stub("0xaa"), .stub("0xbb")]))
        let completed = AsyncExpectation()
        let results = Recorded<SubmitIndexedExtrinsicResult>()

        context.submitIndexed(IndexSet([2, 5])) { result in
            results.record(result)
            completed.fulfill()
        }

        try completed.wait()
        let indexed = try #require(results.first)
        #expect(indexed.results.map(\.index) == [2, 5], "results must carry the caller's index values")
        #expect(try indexed.results[0].result.get().txHash == "0xaa")
        #expect(try indexed.results[1].result.get().txHash == "0xbb")
    }

    @Test("a partial submission failure does not affect the other indexes")
    func partialFailureIsIndependent() throws {
        let context = Context(buildExtrinsics: .success([.stub("0xaa"), .stub("0xbb")]))
        context.submitter.submitHandler = { extrinsics in
            [
                .success(ExtrinsicSubmittedModel(txHash: extrinsics[0].extrinsic, sender: .none)),
                .failure(TestError.submission)
            ]
        }
        let completed = AsyncExpectation()
        let results = Recorded<SubmitIndexedExtrinsicResult>()

        context.submitIndexed(IndexSet([2, 5])) { result in
            results.record(result)
            completed.fulfill()
        }

        try completed.wait()
        let indexed = try #require(results.first)
        #expect(try indexed.results[0].result.get().txHash == "0xaa")
        guard case .failure = indexed.results[1].result else {
            Issue.record("expected index 5 to fail independently")
            return
        }
    }

    @Test("an indexed build failure yields one failure per index")
    func indexedBuildFailureFailsEveryIndex() throws {
        let context = Context(buildExtrinsics: .failure(TestError.build))
        let completed = AsyncExpectation()
        let results = Recorded<SubmitIndexedExtrinsicResult>()

        context.submitIndexed(IndexSet([2, 5])) { result in
            results.record(result)
            completed.fulfill()
        }

        try completed.wait()
        let indexed = try #require(results.first)
        #expect(indexed.results.map(\.index) == [2, 5])
        #expect(indexed.results.allSatisfy { if case .failure = $0.result { true } else { false } })
        #expect(context.submitter.submitCalls.isEmpty, "nothing may be submitted when building failed")
    }

    @Test("submitWithTxSplitter asks for indexes 0..<numberOfExtrinsics")
    func splitterMapsNumberOfExtrinsicsToIndexes() throws {
        let context = Context(buildExtrinsics: .success([.stub("0xaa"), .stub("0xbb"), .stub("0xcc")]))
        let completed = AsyncExpectation()

        context.service.submitWithTxSplitter(
            ExtrinsicSplittingMock(numberOfExtrinsics: 3),
            origin: ExtrinsicOriginDefiningMock(),
            payingIn: nil,
            runningIn: context.queue
        ) { _ in completed.fulfill() }

        try completed.wait()
        #expect(context.factory.requestedIndexes == [IndexSet(0 ..< 3)])
    }
}

// MARK: - Context

private extension ExtrinsicServiceRoutingTests {
    struct Context {
        let factory: ExtrinsicOperationFactoryMock
        let submitter: ExtrinsicSubmittingMock
        let service: ExtrinsicService
        let queue: DispatchQueue

        init(
            buildExtrinsic: Result<ExtrinsicBuiltModel, Error> = .success(.stub("0x01")),
            buildExtrinsics: Result<[ExtrinsicBuiltModel], Error> = .success([])
        ) {
            factory = ExtrinsicOperationFactoryMock(
                buildExtrinsicResult: buildExtrinsic,
                buildExtrinsicsResult: buildExtrinsics
            )
            submitter = ExtrinsicSubmittingMock()
            queue = makeCallbackQueue()
            service = ExtrinsicService(
                operationFactory: factory,
                operationQueue: OperationQueue(),
                submitter: submitter
            )
        }

        func submitAndWatch(
            notificationClosure: @escaping ExtrinsicSubscriptionStatusClosure = { _ in }
        ) {
            service.submitAndWatch(
                { $0 },
                origin: ExtrinsicOriginDefiningMock(),
                payingIn: nil,
                runningIn: queue,
                subscriptionIdClosure: { _ in true },
                notificationClosure: notificationClosure
            )
        }

        func submitIndexed(
            _ indexes: IndexSet,
            completion: @escaping ExtrinsicSubmitIndexedClosure
        ) {
            service.submit(
                { builder, _ in builder },
                origin: ExtrinsicOriginDefiningMock(),
                payingIn: nil,
                runningIn: queue,
                indexes: indexes,
                completion: completion
            )
        }
    }
}
