import Foundation
import SubstrateSdk

/// Result of executing an extrinsic's call, independent of block inclusion.
public enum DispatchStatus {
    case success
    case failure(Substrate.DispatchCallError)

    public init(executionStatus: SubstrateExtrinsicStatus) {
        switch executionStatus {
        case .success:
            self = .success
        case let .failure(failed):
            self = .failure(failed.error)
        }
    }
}
