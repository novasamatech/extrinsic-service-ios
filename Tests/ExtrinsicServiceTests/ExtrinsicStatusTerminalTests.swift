import Testing
import Foundation
@testable import ExtrinsicService

@Suite("Extrinsic Status Terminal Detection")
struct ExtrinsicStatusTerminalTests {
    private let hash = "0x69d25c4f2cfd1eeae88455679f435569024f2e723a403062929e3d4557a531b7"

    private func update(_ status: RemoteExtrinsicStatus) -> ExtrinsicStatusUpdate {
        ExtrinsicStatusUpdate(extrinsicHash: "0xext", extrinsicStatus: .onChain(status))
    }

    // MARK: - inBlock tracking (default, current behavior)

    @Test func inBlockTrackingIsTerminalAtInBlock() {
        #expect(update(.inBlock(hash)).getTerminalBlockHash(trackingTill: .inBlock) == hash)
    }

    @Test func inBlockTrackingIsTerminalAtFinalized() {
        #expect(update(.finalized(hash)).getTerminalBlockHash(trackingTill: .inBlock) == hash)
    }

    // MARK: - finalized tracking (new behavior)

    @Test func finalizedTrackingIgnoresInBlock() {
        #expect(update(.inBlock(hash)).getTerminalBlockHash(trackingTill: .finalized) == nil)
    }

    @Test func finalizedTrackingIsTerminalAtFinalized() {
        #expect(update(.finalized(hash)).getTerminalBlockHash(trackingTill: .finalized) == hash)
    }

    // MARK: - non-inclusion statuses are never terminal for either target

    @Test func readyIsNeverTerminal() {
        #expect(update(.ready).getTerminalBlockHash(trackingTill: .inBlock) == nil)
        #expect(update(.ready).getTerminalBlockHash(trackingTill: .finalized) == nil)
    }

    @Test func retractedIsNeverTerminal() {
        #expect(update(.retracted(hash)).getTerminalBlockHash(trackingTill: .finalized) == nil)
    }

    // MARK: - provisional inBlock hash

    @Test func inBlockHashPresentOnlyForInBlock() {
        #expect(update(.inBlock(hash)).getInBlockHash() == hash)
        #expect(update(.finalized(hash)).getInBlockHash() == nil)
        #expect(update(.ready).getInBlockHash() == nil)
    }

    @Test func inBlockHashNilWhenNotOnChain() {
        let created = ExtrinsicStatusUpdate(extrinsicHash: "0xext", extrinsicStatus: .created)
        #expect(created.getInBlockHash() == nil)
    }
}
