import Foundation
import Operation_iOS

public protocol ChainAsset {
    var chain: ChainModel { get }
    var asset: AssetModel { get }
}

public protocol ChainAssetId: Codable, Hashable {
    var chainId: ChainModel.Id { get }
    var assetId: AssetModel.Id { get }
}

struct ChainAssetIdImpl: ChainAssetId {
    let chainId: ChainModel.Id
    let assetId: AssetModel.Id

    public var stringValue: String { "\(chainId)-\(assetId)" }
}

extension ChainAsset {
    public var chainAssetId: ChainAssetId {
        ChainAssetIdImpl(chainId: chain.chainId, assetId: asset.assetId)
    }
}
