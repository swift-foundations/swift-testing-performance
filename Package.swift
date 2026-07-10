// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-testing-performance",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "TestingPerformance",
            targets: ["TestingPerformance"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-numerics.git", from: "1.0.0"),
        .package(url: "https://github.com/coenttb/swift-memory-allocation.git", from: "0.2.0")
    ],
    targets: [
        .target(
            name: "TestingPerformance",
            dependencies: [
                .product(name: "Numerics", package: "swift-numerics"),
                .product(name: "MemoryAllocation", package: "swift-memory-allocation")
            ]
        ),
        .testTarget(
            name: "TestingPerformance Tests",
            dependencies: ["TestingPerformance"]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let existing = target.swiftSettings ?? []
    target.swiftSettings = existing + [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility")
    ]
}
