import Foundation
import SubstrateSdk
import BigInt

public extension MultisigPallet {
    public struct AsMultiCall<C: Codable>: Codable {
        public typealias CallType = C
        public enum CodingKeys: String, CodingKey {
            case threshold
            case otherSignatories = "other_signatories"
            case maybeTimepoint = "maybe_timepoint"
            case call
            case maxWeight = "max_weight"
        }

        @StringCodable
        public var threshold: MultisigPallet.Threshold
        public let otherSignatories: [BytesCodable]
        @NullCodable
        public var maybeTimepoint: MultisigTimepoint?
        public let call: CallType
        public let maxWeight: Substrate.Weight

        public init(
            threshold: MultisigPallet.Threshold,
            otherSignatories: [BytesCodable],
            maybeTimepoint: MultisigTimepoint? = nil,
            call: CallType,
            maxWeight: Substrate.Weight
        ) {
            self.threshold = threshold
            self.otherSignatories = otherSignatories
            self.maybeTimepoint = maybeTimepoint
            self.call = call
            self.maxWeight = maxWeight
        }
        
        public func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: MultisigPallet.asMultiPath.moduleName,
                callName: MultisigPallet.asMultiPath.callName,
                args: self
            )
        }
    }

    static var asMultiPath: CallCodingPath {
        CallCodingPath(moduleName: Self.name, callName: "as_multi")
    }

    public struct AsMultiThreshold1Call<C: Codable>: Codable {
        public typealias CallType = C
        public enum CodingKeys: String, CodingKey {
            case otherSignatories = "other_signatories"
            case call
        }

        public let otherSignatories: [BytesCodable]
        public let call: CallType
        
        public init(otherSignatories: [BytesCodable], call: CallType) {
            self.otherSignatories = otherSignatories
            self.call = call
        }

        public func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: MultisigPallet.asMultiThreshold1Path.moduleName,
                callName: MultisigPallet.asMultiThreshold1Path.callName,
                args: self
            )
        }
    }

    static var asMultiThreshold1Path: CallCodingPath {
        CallCodingPath(moduleName: Self.name, callName: "as_multi_threshold_1")
    }

    public struct CancelAsMultiCall: Codable {
        public enum CodingKeys: String, CodingKey {
            case threshold
            case otherSignatories = "other_signatories"
            case timepoint
            case callHash = "call_hash"
        }

        @StringCodable var threshold: UInt16
        let otherSignatories: [BytesCodable]
        let timepoint: MultisigTimepoint
        @BytesCodable var callHash: Substrate.CallHash

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: "Multisig",
                callName: "cancel_as_multi",
                args: self
            )
        }
    }
}
