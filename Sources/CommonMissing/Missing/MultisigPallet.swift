import SubstrateSdk
import Operation_iOS
import BigInt

public enum MultisigPallet {
    static var name: String { "Multisig" }

    public struct MultisigDefinition: Codable {
        public enum CodingKeys: String, CodingKey {
            case timepoint = "when"
            case deposit
            case depositor
            case approvals
        }

        let timepoint: MultisigTimepoint
        @StringCodable var deposit: BigUInt
        @BytesCodable var depositor: AccountId
        var approvals: [BytesCodable]
    }

    public struct MultisigTimepoint: Codable {
        @StringCodable var height: BlockNumber
        @StringCodable var index: UInt32
    }

    public struct EventTimePoint: Decodable, Hashable {
        let height: BlockNumber
        let index: UInt32

        public init(
            height: BlockNumber,
            index: UInt32
        ) {
            self.height = height
            self.index = index
        }

        public init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            let height = try unkeyedContainer.decode(StringCodable<BlockNumber>.self)
            let index = try unkeyedContainer.decode(StringCodable<UInt32>.self)

            self.height = height.wrappedValue
            self.index = index.wrappedValue
        }
    }

    public struct CallHashKey: JSONListConvertible, Hashable {
        let accountId: AccountId
        let callHash: Substrate.CallHash

        public init(
            accountId: AccountId,
            callHash: Substrate.CallHash
        ) {
            self.accountId = accountId
            self.callHash = callHash
        }

        public init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            let expectedFieldsCount = 2
            let actualFieldsCount = jsonList.count
            guard expectedFieldsCount == actualFieldsCount else {
                throw JSONListConvertibleError.unexpectedNumberOfItems(
                    expected: expectedFieldsCount,
                    actual: actualFieldsCount
                )
            }

            accountId = try jsonList[0].map(to: BytesCodable.self, with: context).wrappedValue
            callHash = try jsonList[1].map(to: BytesCodable.self, with: context).wrappedValue
        }
    }

    public typealias Threshold = UInt16
}
