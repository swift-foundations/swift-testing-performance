// swift-tools-version: 6.3.3

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
        .package(url: "https://github.com/swift-primitives/swift-numeric-primitives.git", branch: "main")
    ],
    targets: [
        .target(
            name: "MemoryAllocation",
            dependencies: [
                .target(name: "Allocation Tracking Shims", condition: .when(platforms: [.linux]))
            ],
            path: "Sources/MemoryAllocation"
        ),
        .target(
            name: "Allocation Tracking Shims",
            path: "Sources/Allocation Tracking Shims",
            linkerSettings: [
                .linkedLibrary("dl", .when(platforms: [.linux]))
            ]
        ),
        .target(
            name: "TestingPerformance",
            dependencies: [
                .product(name: "Real Primitives", package: "swift-numeric-primitives"),
                .target(name: "MemoryAllocation")
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
