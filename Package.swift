// swift-tools-version: 6.2
import PackageDescription

let packageDir = Context.packageDirectory

let package = Package(
    name: "WasmClient",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
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
                .unsafeFlags([
                    "-I", "\(packageDir)/.build/artifacts/flow-kit/FlowKit/FlowKit.xcframework/ios-arm64_x86_64-simulator/FlowKit.framework/Modules",
                ]),
            ]
        ),
    ]
)
