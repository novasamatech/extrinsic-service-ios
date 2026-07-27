import Testing
import Foundation
import SubstrateSdk
@testable import ExtrinsicService

@Suite("DefaultExtrinsicSubmitter")
struct DefaultExtrinsicSubmitterTests {
    static let extrinsic = "0x0401"

    @Test("created is emitted first, on the caller's queue, with the blake2b hash")
    func emitsCreatedFirst() throws {
        let context = Context()
        let notified = AsyncExpectation()
        let statuses = Recorded<Result<ExtrinsicSubscribedStatusModel, Error>>()

        context.submitAndSubscribe { result in
            statuses.record(result)
            notified.fulfill()
        }

        try notified.wait()
        let model = try #require(statuses.first).get()
        guard case .created = model.statusUpdate.extrinsicStatus else {
            Issue.record("the first status must be .created")
            return
        }

        let expectedHash = try Data(hexString: Self.extrinsic).blake2b32().toHex(includePrefix: true)
        #expect(model.statusUpdate.extrinsicHash == expectedHash)
    }

    @Test("subscribes with the author_submitAndWatchExtrinsic parameters")
    func subscribesWithExpectedParameters() throws {
        let context = Context()

        context.submitAndSubscribe()

        try context.engine.subscribed.wait()
        let call = try #require(context.engine.subscribeCalls.first)
        #expect(call.method == RPCMethod.submitAndWatchExtrinsic)
        #expect(call.unsubscribeMethod == "author_unwatchExtrinsic")
        #expect(call.params as? [String] == [Self.extrinsic])
        #expect(!call.options.resendOnReconnect, "a submitted extrinsic must not be resent on reconnect")
    }

    @Test("on-chain updates are forwarded on the caller's queue")
    func forwardsOnChainUpdates() throws {
        let context = Context()
        let notified = AsyncExpectation()
        let statuses = Recorded<Result<ExtrinsicSubscribedStatusModel, Error>>()

        context.submitAndSubscribe { result in
            statuses.record(result)
            notified.fulfill()
        }

        try notified.wait()
        context.engine.simulateUpdate(try Self.makeUpdate(status: "ready"))

        try notified.wait()
        let model = try #require(statuses.values.last).get()
        guard case let .onChain(status) = model.statusUpdate.extrinsicStatus else {
            Issue.record("expected an on-chain status")
            return
        }
        #expect(status == .ready)
    }

    @Test("subscription failures are forwarded to the caller")
    func forwardsSubscriptionFailures() throws {
        let context = Context()
        let notified = AsyncExpectation()
        let statuses = Recorded<Result<ExtrinsicSubscribedStatusModel, Error>>()

        context.submitAndSubscribe { result in
            statuses.record(result)
            notified.fulfill()
        }

        try notified.wait()
        context.engine.simulateFailure(TestError.submission)

        try notified.wait()
        guard case .failure = try #require(statuses.values.last) else {
            Issue.record("expected the subscription failure to reach the caller")
            return
        }
    }

    @Test("a declined subscription id unsubscribes but leaves the extrinsic submitted")
    func declinedSubscriptionIdUnsubscribes() throws {
        let context = Context()

        context.submitAndSubscribe(acceptSubscriptionId: false)

        try context.engine.subscribed.wait()
        #expect(context.engine.subscribeCalls.count == 1, "the extrinsic is still submitted")
        #expect(context.engine.cancelledIds == [42], "the watch must be dropped when the caller declines")
    }

    @Test("an undecodable extrinsic fails synchronously, not on the caller's queue")
    func undecodableExtrinsicFailsSynchronously() throws {
        let context = Context()
        let statuses = Recorded<Result<ExtrinsicSubscribedStatusModel, Error>>()

        context.submitter.submitAndSubscribe(
            builtExtrinsic: .stub("not-hex"),
            runningIn: context.queue,
            subscriptionIdClosure: { _ in true },
            notificationClosure: { statuses.record($0) }
        )

        #expect(statuses.count == 1, "the failure is delivered before submitAndSubscribe returns")
        guard case .failure = try #require(statuses.first) else {
            Issue.record("expected a decoding failure")
            return
        }
        #expect(context.engine.subscribeCalls.isEmpty)
    }

    @Test("cancelExtrinsicWatch reaches the connection")
    func cancelReachesConnection() {
        let context = Context()

        context.submitter.cancelExtrinsicWatch(for: 7)

        #expect(context.engine.cancelledIds == [7])
    }
}

// MARK: - Batch submit

extension DefaultExtrinsicSubmitterTests {
    @Test("batch submit issues one author_submitExtrinsic per extrinsic, in order")
    func batchSubmitsEachExtrinsic() throws {
        let context = Context()
        context.engine.callMethodResults = ["0xaa": .success("0xhashA"), "0xbb": .success("0xhashB")]
        let completed = AsyncExpectation()
        let results = Recorded<[SubmitExtrinsicResult]>()

        context.submitter.submit(builtExtrinsics: [.stub("0xaa"), .stub("0xbb")]) { submitResults in
            results.record(submitResults)
            completed.fulfill()
        }

        try completed.wait()
        #expect(context.engine.callMethodCalls.map(\.method) == [
            RPCMethod.submitExtrinsic,
            RPCMethod.submitExtrinsic
        ])
        let submitted = try #require(results.first)
        #expect(try submitted[0].get().txHash == "0xhashA")
        #expect(try submitted[1].get().txHash == "0xhashB")
    }

    @Test("one failing extrinsic in a batch does not affect the others")
    func batchFailureIsIndependent() throws {
        let context = Context()
        context.engine.callMethodResults = ["0xaa": .success("0xhashA"), "0xbb": .failure(TestError.submission)]
        let completed = AsyncExpectation()
        let results = Recorded<[SubmitExtrinsicResult]>()

        context.submitter.submit(builtExtrinsics: [.stub("0xaa"), .stub("0xbb")]) { submitResults in
            results.record(submitResults)
            completed.fulfill()
        }

        try completed.wait()
        let submitted = try #require(results.first)
        #expect(try submitted[0].get().txHash == "0xhashA")
        guard case .failure = submitted[1] else {
            Issue.record("expected the second extrinsic to fail independently")
            return
        }
    }
}

// MARK: - Context

private extension DefaultExtrinsicSubmitterTests {
    struct Context {
        let engine: JSONRPCEngineMock
        let submitter: DefaultExtrinsicSubmitter
        let queue: DispatchQueue

        init() {
            engine = JSONRPCEngineMock()
            queue = makeCallbackQueue()
            submitter = DefaultExtrinsicSubmitter(
                operationFactory: ExtrinsicOperationFactoryMock(connection: engine),
                operationQueue: OperationQueue(),
                timeout: 60
            )
        }

        func submitAndSubscribe(
            acceptSubscriptionId: Bool = true,
            notificationClosure: @escaping ExtrinsicSubscriptionStatusClosure = { _ in }
        ) {
            submitter.submitAndSubscribe(
                builtExtrinsic: .stub(DefaultExtrinsicSubmitterTests.extrinsic),
                runningIn: queue,
                subscriptionIdClosure: { _ in acceptSubscriptionId },
                notificationClosure: notificationClosure
            )
        }
    }

    static func makeUpdate(status: String) throws -> ExtrinsicSubscriptionUpdate {
        let json = """
        {"jsonrpc":"2.0","method":"author_extrinsicUpdate","params":{"subscription":"abc","result":"\(status)"}}
        """

        return try JSONDecoder().decode(ExtrinsicSubscriptionUpdate.self, from: Data(json.utf8))
    }
}
