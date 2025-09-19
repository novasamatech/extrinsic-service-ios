import Foundation
import SubstrateSdk

public extension Proxy {
    public struct ProxyCall: Codable {
        public enum CodingKeys: String, CodingKey {
            case real
            case forceProxyType = "force_proxy_type"
            case call
        }

        public let real: MultiAddress
        public let forceProxyType: Proxy.ProxyType?
        public let call: JSON
        
        public init(real: MultiAddress, forceProxyType: Proxy.ProxyType?, call: JSON) {
            self.real = real
            self.forceProxyType = forceProxyType
            self.call = call
        }

        static var callPath: CallCodingPath {
            CallCodingPath(moduleName: Proxy.name, callName: "proxy")
        }

        public func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: Self.callPath.moduleName,
                callName: Self.callPath.callName,
                args: self
            )
        }
    }

    public struct AddProxyCall: Codable {
        public enum CodingKeys: String, CodingKey {
            case proxy = "delegate"
            case proxyType = "proxy_type"
            case delay
        }

        let proxy: MultiAddress
        let proxyType: ProxyType
        @StringCodable var delay: BlockNumber
    }

    public typealias RemoveProxyCall = AddProxyCall
}
