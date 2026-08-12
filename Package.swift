// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShortcutMap",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ShortcutMap", targets: ["ShortcutMap"])
    ],
    targets: [
        .executableTarget(
            name: "ShortcutMap",
            path: "Sources/ShortcutMap"
        ),
        .testTarget(
            name: "ShortcutMapTests",
            dependencies: ["ShortcutMap"],
            path: "Tests/ShortcutMapTests"
        )
    ]
)
