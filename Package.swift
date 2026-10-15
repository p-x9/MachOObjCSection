// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MachOObjCSection",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "MachOObjCSection",
            targets: ["MachOObjCSection"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/p-x9/MachOKit.git", from: "0.55.0"),
        .package(url: "https://github.com/p-x9/swift-fileio.git", from: "0.14.0"),
        .package(url: "https://github.com/p-x9/swift-objc-dump.git", from: "0.7.0")
    ],
    targets: [
        .target(
            name: "MachOObjCSection",
            dependencies: [
                "MachOObjCSectionC",
                "MachOKit",
                .product(name: "FileIO", package: "swift-fileio"),
                .product(name: "ObjCDump", package: "swift-objc-dump")
            ]
        ),
        .target(
            name: "MachOObjCSectionC"
        ),
        .testTarget(
            name: "MachOObjCSectionTests",
            dependencies: ["MachOObjCSection"]
        )
    ]
)
