// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "stallari-yrs",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "StallariYRS", targets: ["StallariYRS"]),
    ],
    targets: [
        // C module wrapping the Rust static library
        .target(
            name: "CStallariYRS",
            path: "Sources/CStallariYRS",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("stallari_yrs"),
                .unsafeFlags(["-L\(Context.packageDirectory)/lib"], .when(platforms: [.macOS])),
                .unsafeFlags(["-L\(Context.packageDirectory)/lib/ios"], .when(platforms: [.iOS])),
            ]
        ),

        // Swift wrapper providing idiomatic types
        .target(
            name: "StallariYRS",
            dependencies: ["CStallariYRS"],
            path: "Sources/StallariYRS"
        ),

        // Tests
        .testTarget(
            name: "StallariYRSTests",
            dependencies: ["StallariYRS"],
            path: "Tests/StallariYRSTests"
        ),
    ]
)
