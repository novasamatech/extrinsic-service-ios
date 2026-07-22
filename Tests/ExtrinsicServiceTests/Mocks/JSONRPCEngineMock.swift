import Foundation
import SubstrateSdk

final class JSONRPCEngineMock: JSONRPCEngine, @unchecked Sendable {
    struct SubscribeCall {
        let method: String
        let unsubscribeMethod: String
        let params: Any?
        let options: JSONRPCOptions
    }

    struct CallMethodCall {
        let method: String
        let params: Any?
        let options: JSONRPCOptions
    }

    let subscribed = AsyncExpectation()
    let called = AsyncExpectation()

    var identifiers: [UInt16] = [42, 57, 63]

    var callMethodResults: [String: Result<String, Error>] = [:]

    private let lock = NSLock()
    private let completionQueue = DispatchQueue(label: "extrinsic.service.tests.engine")
    private var storedSubscribeCalls: [SubscribeCall] = []
    private var storedCallMethodCalls: [CallMethodCall] = []
    private var storedCancelledIds: [UInt16] = []
    private var storedIssuedIds = 0
    private var updateHandlers: [(Any) -> Void] = []
    private var failureHandlers: [(Error, Bool) -> Void] = []

    var subscribeCalls: [SubscribeCall] { lock.withLock { storedSubscribeCalls } }
    var callMethodCalls: [CallMethodCall] { lock.withLock { storedCallMethodCalls } }
    var cancelledIds: [UInt16] { lock.withLock { storedCancelledIds } }

    func callMethod<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        let key = Self.firstStringParam(params)

        let result: Result<String, Error>? = lock.withLock {
            storedCallMethodCalls.append(CallMethodCall(method: method, params: params, options: options))
            return key.flatMap { callMethodResults[$0] } ?? .success("0xdefault")
        }

        let identifier = nextIdentifier()

        called.fulfill()

        let outcome: Result<T, Error>

        switch result {
        case let .success(value):
            let data = try JSONEncoder().encode(value)
            outcome = try .success(JSONDecoder().decode(T.self, from: data))
        case let .failure(error):
            outcome = .failure(error)
        case .none:
            return identifier
        }

        completionQueue.async { closure?(outcome) }

        return identifier
    }

    func subscribe<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        unsubscribeMethod: String,
        options: JSONRPCOptions,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        let call = SubscribeCall(
            method: method,
            unsubscribeMethod: unsubscribeMethod,
            params: params,
            options: options
        )

        lock.withLock {
            storedSubscribeCalls.append(call)
            updateHandlers.append { anyUpdate in
                guard let typed = anyUpdate as? T else { return }
                updateClosure(typed)
            }
            failureHandlers.append(failureClosure)
        }

        let identifier = nextIdentifier()

        subscribed.fulfill()

        return identifier
    }

    func cancelForIdentifiers(_ identifiers: [UInt16]) {
        lock.withLock { storedCancelledIds.append(contentsOf: identifiers) }
    }

    func addBatchCallMethod<P: Encodable>(_: String, params _: P?, batchId _: JSONRPCBatchId) throws {
        fatalError("unused in tests")
    }

    func submitBatch(
        for _: JSONRPCBatchId,
        options _: JSONRPCOptions,
        completion _: (([Result<JSON, Error>]) -> Void)?
    ) throws -> [UInt16] {
        fatalError("unused in tests")
    }

    func clearBatch(for _: JSONRPCBatchId) {
        fatalError("unused in tests")
    }
}

extension JSONRPCEngineMock {
    func simulateUpdate(_ update: Any, atSubscription index: Int = 0) {
        let handler: ((Any) -> Void)? = lock.withLock {
            index < updateHandlers.count ? updateHandlers[index] : nil
        }

        handler?(update)
    }

    func simulateFailure(_ error: Error, atSubscription index: Int = 0) {
        let handler: ((Error, Bool) -> Void)? = lock.withLock {
            index < failureHandlers.count ? failureHandlers[index] : nil
        }

        handler?(error, false)
    }
}

private extension JSONRPCEngineMock {
    static func firstStringParam<P: Encodable>(_ params: P?) -> String? {
        guard
            let params,
            let data = try? JSONEncoder().encode(params),
            let list = try? JSONDecoder().decode([String].self, from: data)
        else {
            return nil
        }

        return list.first
    }

    func nextIdentifier() -> UInt16 {
        lock.withLock {
            let identifier = storedIssuedIds < identifiers.count
                ? identifiers[storedIssuedIds]
                : UInt16(100 + storedIssuedIds)
            storedIssuedIds += 1
            return identifier
        }
    }
}
