// swift-tools-version: 5.9
// SwipeBackKit — Android-style edge swipe navigation for iOS
// https://github.com/Kumar-ranjan12345/SwipeBackKit

import PackageDescription

let package = Package(
    name: "SwipeBackKit",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "SwipeBackKit",
            targets: ["SwipeBackKit"]
        )
    ],
    targets: [
        .target(
            name: "SwipeBackKit",
            path: "Sources/SwipeBackKit"
        )
    ]
)
