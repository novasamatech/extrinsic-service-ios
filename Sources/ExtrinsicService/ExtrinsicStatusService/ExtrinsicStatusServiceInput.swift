import Foundation
import CommonMissing

struct ExtrinsicStatusServiceInput {
    let extrinsicHash: Data
    let blockHash: BlockHash
    let matchingEvents: ExtrinsicEventsMatching?
}
