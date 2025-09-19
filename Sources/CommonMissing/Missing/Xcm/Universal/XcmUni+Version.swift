import Foundation

extension XcmUni {
    public struct Versioned<Entity> {
        let entity: Entity
        let version: Xcm.Version
    }

    public typealias VersionedMessage = Versioned<XcmUni.Instructions>
    public typealias VersionedAsset = Versioned<XcmUni.Asset>
    public typealias VersionedAssets = Versioned<XcmUni.Assets>
    public typealias VersionedLocation = Versioned<XcmUni.RelativeLocation>
    public typealias VersionedAssetId = Versioned<XcmUni.AssetId>
}

extension XcmUni.Versioned: Equatable where Entity: Equatable {}

public protocol XcmUniVersioned {
    func versioned(_ version: Xcm.Version) -> XcmUni.Versioned<Self>
}

public extension XcmUniVersioned {
    func versioned(_ version: Xcm.Version) -> XcmUni.Versioned<Self> {
        .init(entity: self, version: version)
    }
}

extension XcmUni.RelativeLocation: XcmUniVersioned {}
extension XcmUni.Asset: XcmUniVersioned {}

extension Array: XcmUniVersioned {}

public extension XcmUni.VersionedAsset {
    func toVersionedAssets() -> XcmUni.VersionedAssets {
        [entity].versioned(version)
    }
}

public extension XcmUni.Versioned {
    func map<U>(_ transformation: (Entity) throws -> U) rethrows -> XcmUni.Versioned<U> {
        let newEntity = try transformation(entity)
        return XcmUni.Versioned(entity: newEntity, version: version)
    }
}
