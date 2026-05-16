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
        // C module wrapping the Rust static library — binary-distributed via
        // GH Release per DD-295 Phase C amendment § "Binary-distributed siblings".
        // Bumping: `make release-xcframework` → capture SHA-256 → tag stallari-yrs →
        // bump url + checksum below in lockstep (release-sibling.sh handles this).
        .binaryTarget(
            name: "CStallariYRS",
            url: "https://github.com/groupthink-dev/stallari-yrs/releases/download/0.1.1/stallari_yrs.xcframework.zip",
            checksum: "1d5f14c250d0db606a9c8607729a4d1fcb88c545ba68e86d176fc05987a6e8e5"
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
