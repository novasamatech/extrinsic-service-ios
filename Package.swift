// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ExtrinsicPackage",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "ExtrinsicPackage",
            targets: [
                "ExtrinsicPackage",
            ]),
    ],
    dependencies: [
        .package(url: "https://github.com/novasamatech/substrate-sdk-ios", exact: "4.4.0"),
        .package(url: "https://github.com/novasamatech/Keystore-iOS", exact: "1.0.1"),
        .package(url: "https://github.com/novasamatech/metadata-shortener-ios", exact: "0.2.1"),
    ],
    targets: [
        .target(
            name: "ExtrinsicPackage",
            dependencies: [
                .product(name: "SubstrateSdk", package: "substrate-sdk-ios"),
                .product(name: "MetadataShortenerApi", package: "metadata-shortener-ios"),
                "Keystore-iOS",
                "CommonMissing",
            ]
        ),
        .testTarget(
            name: "ExtrinsicPackageTests",
            dependencies: [
                "ExtrinsicPackage"
            ]
        ),
        .target(
            name: "CommonMissing",
            dependencies: [
                .product(name: "SubstrateSdk", package: "substrate-sdk-ios"),
            ]
        )
    ]
)
