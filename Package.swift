// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapacitorCommunitySqlite",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "CapacitorCommunitySqlite",
            targets: ["CapacitorSQLitePlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0")
    ],
    targets: [
        .target(
            name: "CapacitorSQLitePlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Plugin"),
        .testTarget(
            name: "PluginTests",
            dependencies: ["CapacitorSQLitePlugin"],
            path: "ios/PluginTests",
            exclude: ["basic.json", "assets", "public"])
    ]
)
