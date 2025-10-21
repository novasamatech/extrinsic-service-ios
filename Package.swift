// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ExtrinsicPackage",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "ExtrinsicService",
            targets: [
                "ExtrinsicService",
            ]),
    ],
    dependencies: [
        .package(url: "https://github.com/novasamatech/substrate-sdk-ios", revision: "27c45980b9ac299537b71b37244bcc9285d9086b"),
        .package(url: "https://github.com/novasamatech/Keystore-iOS", exact: "1.0.1"),
        .package(url: "https://github.com/novasamatech/metadata-shortener-ios", exact: "0.2.1"),
    ],
    targets: [
        .target(
            name: "ExtrinsicService",
            dependencies: [
                .product(name: "SubstrateSdk", package: "substrate-sdk-ios"),
                .product(name: "SubstrateMetadataHash", package: "substrate-sdk-ios"),
                .product(name: "SubstrateStorageQuery", package: "substrate-sdk-ios"),
                .product(name: "MetadataShortenerApi", package: "metadata-shortener-ios"),
                "Keystore-iOS"
            ]
        ),
        .testTarget(
            name: "ExtrinsicServiceTests",
            dependencies: [
                "ExtrinsicService"
            ]
        )
    ]
)
