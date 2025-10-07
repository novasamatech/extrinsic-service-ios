import Foundation
import Keystore_iOS

import CommonMissing

public protocol SigningWrapperFactoryProtocol {
    func createSigningWrapper(for account: AccountProtocol) -> SigningWrapperProtocol
    func createDummySigningWrapper(for account: AccountProtocol) -> SigningWrapperProtocol
}
