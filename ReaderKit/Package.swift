// swift-tools-version: 6.2
import PackageDescription

// Apply the same concurrency and warning policy to every ReaderKit target.
// The remaining Approachable Concurrency features are already enabled in Swift 6 mode.
let readerSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .treatAllWarnings(as: .error)
]

let package = Package(
    name: "ReaderKit",
    defaultLocalization: "en",
    platforms: [.macOS("27.0"), .iOS("27.0")],
    products: ["ReaderDomain", "ReaderPersistence", "ReaderSync", "ReaderContent", "ReaderIntelligence", "ReaderUI"].map {
        .library(name: $0, targets: [$0])
    } + [.executable(name: "ReaderStoreRecoveryProbe", targets: ["ReaderStoreRecoveryProbe"])],
    targets: [
        .executableTarget(
            name: "ReaderStoreRecoveryProbe",
            dependencies: ["ReaderDomain", "ReaderPersistence"],
            path: "Probes/ReaderStoreRecoveryProbe",
            swiftSettings: readerSwiftSettings
        ),
        .target(name: "ReaderDomain", resources: [.process("Resources")], swiftSettings: readerSwiftSettings),
        .target(
            name: "ReaderPersistence", dependencies: ["ReaderDomain"],
            exclude: ["README.md"], swiftSettings: readerSwiftSettings
        ),
        .target(
            name: "ReaderSync", dependencies: ["ReaderDomain", "ReaderContent"],
            exclude: ["README.md"], resources: [.process("Resources")], swiftSettings: readerSwiftSettings
        ),
        .target(
            name: "ReaderContent", dependencies: ["ReaderDomain"],
            resources: [.process("Resources")], swiftSettings: readerSwiftSettings
        ),
        .target(
            name: "ReaderIntelligence", dependencies: ["ReaderDomain", "ReaderContent"],
            resources: [.process("Resources")], swiftSettings: readerSwiftSettings
        ),
        .target(
            name: "ReaderUI",
            dependencies: ["ReaderDomain", "ReaderPersistence", "ReaderSync", "ReaderContent", "ReaderIntelligence"],
            exclude: ["README.md"], resources: [.process("Resources")], swiftSettings: readerSwiftSettings
        )
    ]
)
