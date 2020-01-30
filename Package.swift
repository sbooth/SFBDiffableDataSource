// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "SFBDiffableDataSource",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "SFBDiffableDataSource", targets: ["SFBDiffableDataSource"]),
    ],
    targets: [
        .target(
            name: "SFBDiffableDataSource",
            path: "SFBDiffableDataSource")
    ]
)
