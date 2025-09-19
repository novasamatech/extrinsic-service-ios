import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

public protocol ChainModel {
    typealias Id = String
    typealias AddressPrefix = UInt64

    var chainId: String { get }
    var parentId: String? { get }
    var assets: [AssetModel] { get }
    var addressPrefix: UInt64 { get }
    var options: [LocalChainOptions]? { get }
    var additional: JSON? { get }
}

extension ChainModel {
    public var isEthereumBased: Bool {
        options?.contains(.ethereumBased) ?? false
    }

    var hasMultisig: Bool {
        options?.contains(where: { $0 == .multisig }) ?? false
    }
    
    var supportsGenericLedgerApp: Bool {
        additional?.supportsGenericLedgerApp?.boolValue ?? false
    }
    
    public var disabledCheckMetadataHash: Bool {
        additional?.disabledCheckMetadataHash?.boolValue ?? false
    }
    
    public var feeViaRuntimeCall: Bool {
        additional?.feeViaRuntimeCall?.boolValue ?? false
    }
    
    public func utilityChainAssetId() -> ChainAssetId? {
        guard
            let utilityAsset = utilityAssets().first
        else {
            return nil
        }

        return ChainAssetIdImpl(chainId: chainId, assetId: utilityAsset.assetId)
    }
    
    public func utilityAssets() -> [AssetModel] {
        assets.filter { $0.isUtility }
    }
    
    public var accountIdSize: Int {
        Self.getAccountIdSize(for: chainFormat)
    }

    static func getAccountIdSize(for chainFormat: ChainFormat) -> Int {
        switch chainFormat {
        case .substrate:
            return 32
        case .ethereum:
            return 20
        }
    }
    
    public var defaultTip: BigUInt? {
        if let tipString = additional?.defaultTip?.stringValue {
            return BigUInt(tipString)
        } else {
            return nil
        }
    }
}

public enum LocalChainOptions: String, Codable, Hashable {
    case ethereumBased
    case testnet
    case crowdloans
    case governance
    case governanceV1 = "governance-v1"
    case noSubstrateRuntime
    case swapHub = "swap-hub"
    case swapHydra = "hydradx-swaps"
    case proxy
    case multisig
    case pushNotifications = "pushSupport"
    case assetHubFees = "assethub-fees"
    case hydrationFees = "hydration-fees"
}

public extension ChainModel.AddressPrefix {
    func toSubstrateFormat() -> UInt16 {
        // The assumption is that we don't map values overflowing UInt16
        // in the ChainModel for substrate networks.
        UInt16(self)
    }
}
