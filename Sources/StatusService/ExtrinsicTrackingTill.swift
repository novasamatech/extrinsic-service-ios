import Foundation

/// Terminal state a submission monitor should track an extrinsic until.
public enum ExtrinsicTrackingTill: Equatable {
    /// Complete as soon as the extrinsic is included in a block (or finalized).
    case inBlock
    /// Complete only when the extrinsic's block is finalized.
    case finalized
}
