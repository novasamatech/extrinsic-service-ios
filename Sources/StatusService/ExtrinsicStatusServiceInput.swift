import Foundation
import SubstrateSdk

struct ExtrinsicStatusServiceInput {
    let extrinsicHash: Data
    let blockHash: BlockHash
    let matchingEvents: ExtrinsicEventsMatching?
}
