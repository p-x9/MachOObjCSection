// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MachOObjCSection",
    products: [
        .library(
            name: "MachOObjCSection",
            targets: ["MachOObjCSection"]
        ),
    ],
    dependencies: [
//        .package(url: "https://github.com/p-x9/MachOKit.git", exact: "0.19.0"),
        .package(url: "https://github.com/p-x9/MachOKit.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "MachOObjCSection",
            dependencies: [
                "MachOObjCSectionC",
                "MachOKit",
            ]
        ),
        .target(
            name: "MachOObjCSectionC"
        ),
        .testTarget(
            name: "MachOObjCSectionTests",
            dependencies: ["MachOObjCSection"]
        ),
    ]
)
