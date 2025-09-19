import Foundation
import Operation_iOS

public extension DelegatedAccount {
    struct ProxyAccountModel: DelegatedAccountProtocol {
        public let type: Proxy.ProxyType
        public let accountId: AccountId
        public let status: Status
    }
}

extension DelegatedAccount.ProxyAccountModel: Operation_iOS.Identifiable {
    public var identifier: String {
        type.id + "-" + accountId.toHex()
    }

    var isRevoked: Bool {
        status == .revoked
    }
}

public extension DelegatedAccount.ProxyAccountModel {
    func replacingStatus(
        _ newStatus: DelegatedAccount.Status
    ) -> DelegatedAccount.ProxyAccountModel {
        .init(type: type, accountId: accountId, status: newStatus)
    }
}

public extension DelegatedAccount.ProxyAccountModel {
    var isNotActive: Bool {
        status == .new || status == .revoked
    }
}

public extension Array where Element: DelegatedAccountProtocol {
    var hasNotActive: Bool {
        contains { $0.status == .new || $0.status == .revoked }
    }
}
