import Foundation
import SubstrateSdk

struct PartialBuildersModel {
    let builders: [ExtrinsicBuilderProtocol]
    let mortality: ExtrinsicMortality
}
