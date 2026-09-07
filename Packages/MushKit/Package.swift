// swift-tools-version: 6.0
import PackageDescription

// Two targets on purpose:
//
//   MushKit        pure Swift, Foundation only. Models, brain-health engine, ledger,
//                  threshold-ladder maths. Builds and tests anywhere, including a CI
//                  runner with no simulator. This is where the logic that must be
//                  provably correct lives.
//
//   MushScreenTime the FamilyControls / ManagedSettings / DeviceActivity glue. iOS-only,
//                  guarded with #if os(iOS) so `swift test` still works on the runner.
//
// Both must stay dependency-free: Screen Time extensions run under a very tight memory
// budget (docs/01-FEASIBILITY.md L9) and link this code.

let package = Package(
    name: "MushKit",
    platforms: [.iOS(.v26), .macOS(.v14)],
    products: [
        .library(name: "MushKit", targets: ["MushKit"]),
        .library(name: "MushScreenTime", targets: ["MushScreenTime"]),
    ],
    targets: [
        .target(
            name: "MushKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "MushScreenTime",
            dependencies: ["MushKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "MushKitTests",
            dependencies: ["MushKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
