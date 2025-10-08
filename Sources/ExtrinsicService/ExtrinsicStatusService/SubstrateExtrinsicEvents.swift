import Foundation
import SubstrateSdk

public struct SubstrateBlockDetails {
    let extrinsicsWithEvents: SubstrateExtrinsicsEvents
    let inherentsEvents: SubstrateInherentsEvents
}

public struct SubstrateExtrinsicEvents {
    let extrinsicHash: Data
    let extrinsicData: Data
    let eventRecords: [EventRecord]
}

typealias SubstrateExtrinsicsEvents = [SubstrateExtrinsicEvents]

public struct SubstrateInherentsEvents {
    let initialization: [Event]
    let finalization: [Event]
}
