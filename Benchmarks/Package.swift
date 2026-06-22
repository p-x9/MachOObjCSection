// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MachOObjCSectionBenchmarks",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/p-x9/MachOKit.git", exact: "0.46.1"),
        .package(url: "https://github.com/p-x9/swift-fileio.git", exact: "0.13.0"),
        .package(url: "https://github.com/p-x9/swift-objc-dump.git", exact: "0.7.0"),
        .package(url: "https://github.com/ordo-one/benchmark", from: "1.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "MachOObjCSectionBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "FileIO", package: "swift-fileio"),
                .product(name: "MachOKit", package: "MachOKit"),
                .product(name: "MachOObjCSection", package: "MachOObjCSection"),
                .product(name: "ObjCDump", package: "swift-objc-dump"),
            ],
            path: "Benchmarks/MachOObjCSectionBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark")
            ]
        )
    ]
)
