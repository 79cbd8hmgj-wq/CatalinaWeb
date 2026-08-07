// swift-tools-version:5.3
import PackageDescription

var products: [Product] = [
    .library(name: "CatalinaWebCore", targets: ["CatalinaWebCore"])
]

var targets: [Target] = [
    .target(name: "CatalinaWebCore"),
    .testTarget(
        name: "CatalinaWebCoreTests",
        dependencies: ["CatalinaWebCore"]
    )
]

#if os(macOS)
products.append(.executable(name: "CatalinaWeb", targets: ["CatalinaWeb"]))
targets.insert(
    .target(
        name: "CatalinaProcessMetrics",
        publicHeadersPath: "include",
        linkerSettings: [.linkedLibrary("proc")]
    ),
    at: 1
)
targets.insert(
    .target(
        name: "CatalinaWebApp",
        dependencies: ["CatalinaWebCore", "CatalinaProcessMetrics"]
    ),
    at: 2
)
targets.insert(
    .target(
        name: "CatalinaWeb",
        dependencies: ["CatalinaWebApp"]
    ),
    at: 3
)
targets.append(
    .testTarget(
        name: "CatalinaWebMacTests",
        dependencies: ["CatalinaWebApp", "CatalinaWebCore", "CatalinaProcessMetrics"]
    )
)
#endif

let package = Package(
    name: "CatalinaWeb",
    platforms: [.macOS(.v10_15)],
    products: products,
    targets: targets
)
