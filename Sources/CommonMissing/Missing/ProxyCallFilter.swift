import Foundation

public protocol ProxyCallFilterProtocol {
    func matches(call: CallCodingPath) -> Bool
}

public extension ProxyCallFilter {
    public struct ConstantMatches: ProxyCallFilterProtocol {
        let result: Bool

        public init(result: Bool) {
            self.result = result
        }

        public func matches(call _: CallCodingPath) -> Bool {
            result
        }
    }

    public struct MatchesPallet: ProxyCallFilterProtocol {
        let palletPossibleNames: Set<String>

        public init(pallet: String) {
            palletPossibleNames = [pallet]
        }

        public init(palletPossibleNames: Set<String>) {
            self.palletPossibleNames = palletPossibleNames
        }

        public func matches(call: CallCodingPath) -> Bool {
            palletPossibleNames.contains(call.moduleName)
        }
    }

    public struct MatchesCall: ProxyCallFilterProtocol {
        let callPath: CallCodingPath

        public init(callPath: CallCodingPath) {
            self.callPath = callPath
        }

        public func matches(call: CallCodingPath) -> Bool {
            callPath == call
        }
    }

    struct NotMatches: ProxyCallFilterProtocol {
        let innerFilter: ProxyCallFilterProtocol

        public init(innerFilter: ProxyCallFilterProtocol) {
            self.innerFilter = innerFilter
        }

        public func matches(call: CallCodingPath) -> Bool {
            !innerFilter.matches(call: call)
        }
    }

    struct OrMatches: ProxyCallFilterProtocol {
        let innerFilters: [ProxyCallFilterProtocol]

        public init(innerFilters: [ProxyCallFilterProtocol]) {
            self.innerFilters = innerFilters
        }

        public func matches(call: CallCodingPath) -> Bool {
            innerFilters.contains { $0.matches(call: call) }
        }
    }
}

public enum ProxyCallFilter {
    private static var proxyTypeToFilter: [Proxy.ProxyType: ProxyCallFilterProtocol] {
        [
            Proxy.ProxyType.any: ConstantMatches(result: true),
            Proxy.ProxyType.nonTransfer: OrMatches(
                innerFilters: [
                    MatchesPallet(pallet: "System"),
                    MatchesPallet(pallet: "Scheduler"),
                    MatchesPallet(pallet: "Babe"),
                    MatchesPallet(pallet: "Timestamp"),
                    MatchesCall(callPath: .init(moduleName: "Indices", callName: "claim")),
                    MatchesCall(callPath: .init(moduleName: "Indices", callName: "free")),
                    MatchesCall(callPath: .init(moduleName: "Indices", callName: "freeze")),
                    // Specifically omitting Indices `transfer`, `force_transfer`
                    // Specifically omitting the entire Balances pallet
                    MatchesPallet(pallet: "Staking"),
                    MatchesPallet(pallet: "Session"),
                    MatchesPallet(pallet: "Grandpa"),
                    MatchesPallet(pallet: "ImOnline"),
                    MatchesPallet(pallet: "Treasury"),
                    MatchesPallet(pallet: "Bounties"),
                    MatchesPallet(pallet: "ChildBounties"),
                    MatchesPallet(pallet: "ConvictionVoting"),
                    MatchesPallet(pallet: "Referenda"),
                    MatchesPallet(pallet: "Whitelist"),
                    MatchesPallet(pallet: "Claims"),
                    MatchesCall(callPath: .init(moduleName: "Vesting", callName: "vest")),
                    MatchesCall(callPath: .init(moduleName: "Vesting", callName: "vest_other")),
                    // Specifically omitting Vesting `vested_transfer`, and `force_vested_transfer`
                    MatchesPallet(pallet: "Utility"),
                    MatchesPallet(pallet: "Identity"),
                    MatchesPallet(pallet: "Proxy"),
                    MatchesPallet(pallet: "Multisig"),
                    MatchesCall(callPath: .init(moduleName: "Registrar", callName: "register")),
                    MatchesCall(callPath: .init(moduleName: "Registrar", callName: "deregister")),
                    // Specifically omitting Registrar `swap`
                    MatchesCall(callPath: .init(moduleName: "Registrar", callName: "reserve")),
                    MatchesPallet(pallet: "Crowdloan"),
                    MatchesPallet(pallet: "Slots"),
                    MatchesPallet(pallet: "Auctions"),
                    MatchesPallet(palletPossibleNames: Set(BagList.possibleModuleNames)),
                    MatchesPallet(pallet: "NominationPools"),
                    MatchesPallet(pallet: "FastUnstake")
                ]
            ),
            Proxy.ProxyType.governance: OrMatches(
                innerFilters: [
                    MatchesPallet(pallet: "ConvictionVoting"),
                    MatchesPallet(pallet: "Referenda"),
                    MatchesPallet(pallet: "Treasury"),
                    MatchesPallet(pallet: "Bounties"),
                    MatchesPallet(pallet: "ChildBounties"),
                    MatchesPallet(pallet: "Whitelist"),
                    MatchesPallet(pallet: "Democracy"),
                    MatchesPallet(pallet: "Utility")
                ]
            ),
            Proxy.ProxyType.staking: OrMatches(
                innerFilters: [
                    MatchesPallet(pallet: "Staking"),
                    MatchesPallet(pallet: "NominationPools"),
                    MatchesPallet(palletPossibleNames: Set(BagList.possibleModuleNames)),
                    MatchesPallet(pallet: "FastUnstake"),
                    MatchesPallet(pallet: "Session"),
                    MatchesPallet(pallet: "Utility")
                ]
            ),
            Proxy.ProxyType.nominationPools: OrMatches(
                innerFilters: [
                    MatchesPallet(pallet: "NominationPools"),
                    MatchesPallet(pallet: "Utility")
                ]
            ),
            Proxy.ProxyType.auction: OrMatches(
                innerFilters: [
                    MatchesPallet(pallet: "Auctions"),
                    MatchesPallet(pallet: "Crowdloan"),
                    MatchesPallet(pallet: "Registrar"),
                    MatchesPallet(pallet: "Slots")
                ]
            ),
            Proxy.ProxyType.cancelProxy: MatchesCall(
                callPath: .init(moduleName: Proxy.name, callName: "reject_announcement")
            ),
            Proxy.ProxyType.identityJudgement: OrMatches(
                innerFilters: [
                    MatchesCall(callPath: .init(moduleName: "Identity", callName: "provide_judgement")),
                    MatchesPallet(pallet: "Utility")
                ]
            )
        ]
    }

    public static func getProxyTypes(for call: CallCodingPath) -> Set<Proxy.ProxyType> {
        let types = proxyTypeToFilter
            .filter { $0.value.matches(call: call) }
            .keys

        return Set(types)
    }
}
