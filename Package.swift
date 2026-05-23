// swift-tools-version: 5.9
// SwipeBack — Android-style edge swipe navigation for iOS
// https://github.com/Kumar-ranjan12345/SwipeBack

import PackageDescription

let package = Package(
    name: "SwipeBack",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "SwipeBack",
            targets: ["SwipeBack"]
        )
    ],
    targets: [
        .target(
            name: "SwipeBack",
            path: "Sources/SwipeBack"
        )
    ]
)
