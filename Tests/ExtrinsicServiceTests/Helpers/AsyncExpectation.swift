import Foundation

struct ExpectationTimeoutError: Error {}

final class AsyncExpectation: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)

    func fulfill() {
        semaphore.signal()
    }

    func wait(count: Int = 1, timeout: TimeInterval = 2) throws {
        for _ in 0 ..< count {
            guard semaphore.wait(timeout: .now() + timeout) == .success else {
                throw ExpectationTimeoutError()
            }
        }
    }
}

final class Recorded<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Value] = []

    var values: [Value] {
        lock.withLock { storage }
    }

    var first: Value? {
        values.first
    }

    var count: Int {
        values.count
    }

    func record(_ value: Value) {
        lock.withLock { storage.append(value) }
    }
}

enum TestError: Error {
    case build
    case submission
}

func makeCallbackQueue() -> DispatchQueue {
    DispatchQueue(label: "extrinsic.service.tests.callback")
}
