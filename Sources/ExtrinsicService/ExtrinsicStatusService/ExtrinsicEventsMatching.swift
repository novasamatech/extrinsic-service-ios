import Foundation
import SubstrateSdk

public enum ExtrinsicEventsMatcherError: Error {
    case eventCodingPathFailed
}

public protocol ExtrinsicEventsMatching {
    func match(
        event: Event,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> Bool
}

public extension ExtrinsicEventsMatching {
    func firstMatchingFromList(
        _ events: [Event],
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> Event? {
        events.first { match(event: $0, using: codingFactory) }
    }

    func matchList(
        _ events: [Event],
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> Bool {
        firstMatchingFromList(events, using: codingFactory) != nil
    }
}

public struct ExtrinsicSuccessEventMatcher: ExtrinsicEventsMatching {
    public init() {}
    
    public func match(
        event: Event,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> Bool {
        codingFactory.metadata.eventMatches(event, path: SystemPallet.extrinsicSuccessEventPath)
    }
}

public struct ExtrinsicFailureEventMatcher: ExtrinsicEventsMatching {
    public init() {}
    
    public func match(
        event: Event,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> Bool {
        codingFactory.metadata.eventMatches(event, path: SystemPallet.extrinsicFailedEventPath)
    }
}
