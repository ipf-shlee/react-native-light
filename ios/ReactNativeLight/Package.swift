// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReactNativeLight",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "ReactNativeLight", targets: ["ReactNativeLight"]),
    ],
    targets: [
        .target(name: "ReactNativeLight", path: "Sources"),
    ]
)
