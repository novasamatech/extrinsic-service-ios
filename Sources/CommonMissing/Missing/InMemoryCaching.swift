import Foundation

public class InMemoryCache<K: Hashable, V> {
    private var cache: [K: V]
    private let mutex = NSLock()

    public init(with dict: [K: V] = [:]) {
        cache = dict
    }

    public func fetchValue(for key: K) -> V? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return cache[key]
    }

    public func store(value: V, for key: K) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        cache[key] = value
    }

    public func fetchAllValues() -> [V] {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return Array(cache.values)
    }

    public func removeValue(for key: K) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        cache[key] = nil
    }

    public func removeAllValues() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        cache.removeAll()
    }
}

extension InMemoryCache: Equatable where V: Equatable {
    public static func == (lhs: InMemoryCache<K, V>, rhs: InMemoryCache<K, V>) -> Bool {
        lhs.cache == rhs.cache
    }
}
