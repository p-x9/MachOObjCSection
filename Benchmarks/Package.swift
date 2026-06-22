// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MachOObjCSectionBenchmarks",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/ordo-one/benchmark", from: "1.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "MachOObjCSectionBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "MachOObjCSection", package: "MachOObjCSection"),
            ],
            path: "Benchmarks/MachOObjCSectionBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark")
            ]
        )
    ]
)
