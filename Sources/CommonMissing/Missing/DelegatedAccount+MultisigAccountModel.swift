import Foundation
import Operation_iOS

public extension DelegatedAccount {
    struct MultisigAccountModel: DelegatedAccountProtocol {
        public let accountId: AccountId
        public let signatory: AccountId
        public let otherSignatories: [AccountId]
        public let threshold: Int
        public let status: Status
    }
}
