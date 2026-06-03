// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ToompieTermShell",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ToompieTermShell", targets: ["ToompieTermShell"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "ToompieTermShell",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/ToompieTermShell"
        )
    ]
)
