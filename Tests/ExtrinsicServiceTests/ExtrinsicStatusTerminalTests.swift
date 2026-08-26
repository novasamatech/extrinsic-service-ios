import Testing
import Foundation
@testable import ExtrinsicService

@Suite("Extrinsic Status Terminal Detection")
struct ExtrinsicStatusTerminalTests {
    private let blockHash = "0x69d25c4f2cfd1eeae88455679f435569024f2e723a403062929e3d4557a531b7"
    private let extrinsicHash = "0x69d25c4f2cfd1eeae88455679f435569024f2e723a403062929e3d4557a542c8"

    private func update(_ status: RemoteExtrinsicStatus) -> ExtrinsicStatusUpdate {
        ExtrinsicStatusUpdate(extrinsicHash: extrinsicHash, extrinsicStatus: .onChain(status))
    }

    // MARK: - inBlock tracking (default, current behavior)

    @Test func inBlockTrackingIsTerminalAtInBlock() {
        #expect(update(.inBlock(blockHash)).getTerminalBlockHash(trackingTill: .inBlock) == blockHash)
    }

    @Test func inBlockTrackingIsTerminalAtFinalized() {
        #expect(update(.finalized(blockHash)).getTerminalBlockHash(trackingTill: .inBlock) == blockHash)
    }

    // MARK: - finalized tracking (new behavior)

    @Test func finalizedTrackingIgnoresInBlock() {
        #expect(update(.inBlock(blockHash)).getTerminalBlockHash(trackingTill: .finalized) == nil)
    }

    @Test func finalizedTrackingIsTerminalAtFinalized() {
        #expect(update(.finalized(blockHash)).getTerminalBlockHash(trackingTill: .finalized) == blockHash)
    }

    // MARK: - non-inclusion statuses are never terminal for either target

    @Test func readyIsNeverTerminal() {
        #expect(update(.ready).getTerminalBlockHash(trackingTill: .inBlock) == nil)
        #expect(update(.ready).getTerminalBlockHash(trackingTill: .finalized) == nil)
    }

    @Test func retractedIsNeverTerminal() {
        #expect(update(.retracted(blockHash)).getTerminalBlockHash(trackingTill: .finalized) == nil)
    }
}
