import Foundation
import SubstrateSdk

public protocol SigningWrapperFactoryProtocol {
    func createSigningWrapper(for account: AccountProtocol) -> SigningWrapperProtocol
    func createDummySigningWrapper(for account: AccountProtocol) -> SigningWrapperProtocol
}
