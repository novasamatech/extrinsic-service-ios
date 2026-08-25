import Testing
import Foundation
import SubstrateSdk
@testable import ExtrinsicService

@Suite("DispatchStatus mapping")
struct DispatchStatusTests {
    private func success() -> SubstrateExtrinsicStatus {
        .success(.init(
            extrinsicHash: "0xext",
            blockHash: "0xblock",
            blockNumber: 42,
            extrinsicIndex: 1,
            interestedEvents: []
        ))
    }

    private func failure(_ error: Substrate.DispatchCallError) -> SubstrateExtrinsicStatus {
        .failure(.init(
            extrinsicHash: "0xext",
            blockHash: "0xblock",
            blockNumber: 42,
            extrinsicIndex: 1,
            error: error
        ))
    }

    @Test func mapsSuccessStatus() {
        guard case .success = DispatchStatus(executionStatus: success()) else {
            Issue.record("expected .success")
            return
        }
    }

    @Test func mapsFailureStatusPreservingError() {
        let error = Substrate.DispatchCallError.other(.init(module: "Balances", reason: "InsufficientBalance"))

        guard case let .failure(mapped) = DispatchStatus(executionStatus: failure(error)),
              case let .other(other) = mapped else {
            Issue.record("expected .failure(.other)")
            return
        }

        #expect(other.module == "Balances")
        #expect(other.reason == "InsufficientBalance")
    }

    @Test func executionCarriesBlockHashAndStatus() {
        let execution = ExtrinsicExecution(blockHash: "0xblock", dispatchStatus: .success)

        #expect(execution.blockHash == "0xblock")
        guard case .success = execution.dispatchStatus else {
            Issue.record("expected .success")
            return
        }
    }
}
