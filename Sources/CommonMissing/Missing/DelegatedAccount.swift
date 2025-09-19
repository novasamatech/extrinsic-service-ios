import Foundation
import Operation_iOS

public protocol DelegatedAccountProtocol: Hashable {
    var accountId: AccountId { get }
    var status: DelegatedAccount.Status { get }
}

public enum DelegatedAccount {
    public enum Status: String, CaseIterable {
        case new
        case active
        case revoked
    }
}
