import Foundation
import SubstrateSdk

public enum ExtrinsicSenderResolution {
    case none
    case current(AccountProtocol)

    public var account: AccountProtocol? {
        switch self {
        case .none:
            return nil
        case let .current(account):
            return account
        }
    }
}

public typealias ExtrinsicSenderBuilderResolution = (sender: ExtrinsicSenderResolution, builders: [ExtrinsicBuilderProtocol])

public protocol ExtrinsicSenderResolving: AnyObject {
    func resolveSender(
        wrapping builders: [ExtrinsicBuilderProtocol],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicSenderBuilderResolution
}

public final class ExtrinsicCurrentSenderResolver: ExtrinsicSenderResolving {
    let currentAccount: AccountProtocol

    public init(currentAccount: AccountProtocol) {
        self.currentAccount = currentAccount
    }

    public func resolveSender(
        wrapping builders: [ExtrinsicBuilderProtocol],
        codingFactory _: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicSenderBuilderResolution {
        (.current(currentAccount), builders)
    }
}
