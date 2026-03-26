// swift-tools-version: 6.2
import PackageDescription

let packageDir = Context.packageDirectory

// FlowKit.xcframework contains sub-modules (AsyncWasm, TaskWasm, etc.) that
// aren't exposed as SPM products. We need -I flags pointing to the framework's
// Modules/ directory so the compiler can resolve them.
//
// The xcframework lives in different locations depending on the build context:
//   - Local (root package): .build/artifacts/flow-kit/FlowKit/FlowKit.xcframework
//   - Consumer (dependency):  ../../artifacts/flow-kit/FlowKit/FlowKit.xcframework
//
// We add both device and simulator slice paths — the compiler picks the correct
// architecture and silently ignores paths that don't exist.
let flowKitModulePaths: [String] = {
    let xcfwPaths = [
        // Local development (WasmClient is the root package)
        "\(packageDir)/.build/artifacts/flow-kit/FlowKit/FlowKit.xcframework",
        // Consumed as a dependency (Xcode or SPM resolver)
        "\(packageDir)/../../artifacts/flow-kit/FlowKit/FlowKit.xcframework",
    ]
    let slices = [
        "ios-arm64/FlowKit.framework/Modules",
        "ios-arm64_x86_64-simulator/FlowKit.framework/Modules",
    ]
    // Also keep the pre-merged directory for backwards compatibility
    var paths = ["-I", "\(packageDir)/.build/flowkit-merged-modules"]
    for xcfw in xcfwPaths {
        for slice in slices {
            paths += ["-I", "\(xcfw)/\(slice)"]
        }
    }
    return paths
}()

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
                .unsafeFlags(flowKitModulePaths),
            ]
        ),
    ]
)
