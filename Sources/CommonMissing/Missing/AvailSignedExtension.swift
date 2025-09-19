import Foundation
import SubstrateSdk

public enum AvailSignedExtension {
    static let checkAppId = "CheckAppId"

    public final class CheckAppId: Codable, OnlyExplicitTransactionExtending {
        public var txExtensionId: String { AvailSignedExtension.checkAppId }

        let appId: UInt32

        public init(appId: UInt32) {
            self.appId = appId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            appId = try container.decode(StringScaleMapper<UInt32>.self).value
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()

            try container.encode(StringScaleMapper(value: appId))
        }
    }
}

public enum AvailSignedExtensionCoders {
    public static func getCoders(for metadata: RuntimeMetadataProtocol) -> [TransactionExtensionCoding] {
        let extensionId = AvailSignedExtension.checkAppId

        guard let extraType = metadata.getSignedExtensionType(for: extensionId) else {
            return []
        }

        return [
            DefaultTransactionExtensionCoder(
                txExtensionId: extensionId,
                extensionExplicitType: extraType
            )
        ]
    }
}
