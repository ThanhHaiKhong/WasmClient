// swift-tools-version: 6.2
import PackageDescription

let packageDir = Context.packageDirectory

let package = Package(
    name: "WasmClient",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "WasmClient", targets: ["WasmClient"]),
        .library(name: "WasmClientLive", targets: ["WasmClientLive"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/apple/swift-protobuf.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/mahainc/flow-kit.git",
            from: "1.2.3"
        ),
    ],
    targets: [
        .target(
            name: "WasmClient",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "WasmClientLive",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "FlowKit", package: "flow-kit"),
                .product(name: "FlowKitCModules", package: "flow-kit"),
                "WasmClient",
            ],
            swiftSettings: [
                // Merged sub-module directory created by MergeFlowKitModules plugin.
                // Contains AsyncWasm, TaskWasm, etc. but NOT FlowKit/SwiftProtobuf
                // (those are resolved by SPM to the correct xcframework slice).
                .unsafeFlags(["-I", "\(packageDir)/.build/flowkit-merged-modules"]),
            ],
            plugins: [
                .plugin(name: "MergeFlowKitModules"),
            ]
        ),
        .plugin(
            name: "MergeFlowKitModules",
            capability: .buildTool()
        ),
    ]
)
