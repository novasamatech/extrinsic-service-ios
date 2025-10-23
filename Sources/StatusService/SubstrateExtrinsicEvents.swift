import Foundation
import SubstrateSdk

public struct SubstrateBlockDetails {
    public let extrinsicsWithEvents: SubstrateExtrinsicsEvents
    public let inherentsEvents: SubstrateInherentsEvents
    
    public init(extrinsicsWithEvents: SubstrateExtrinsicsEvents, inherentsEvents: SubstrateInherentsEvents) {
        self.extrinsicsWithEvents = extrinsicsWithEvents
        self.inherentsEvents = inherentsEvents
    }
}

public struct SubstrateExtrinsicEvents {
    public let extrinsicHash: Data
    public let extrinsicData: Data
    public let eventRecords: [EventRecord]
    
    public init(extrinsicHash: Data, extrinsicData: Data, eventRecords: [EventRecord]) {
        self.extrinsicHash = extrinsicHash
        self.extrinsicData = extrinsicData
        self.eventRecords = eventRecords
    }
}

public typealias SubstrateExtrinsicsEvents = [SubstrateExtrinsicEvents]

public struct SubstrateInherentsEvents {
    public let initialization: [Event]
    public let finalization: [Event]
    
    public init(initialization: [Event], finalization: [Event]) {
        self.initialization = initialization
        self.finalization = finalization
    }
}
