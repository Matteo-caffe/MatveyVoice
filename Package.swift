// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MatveyVoice",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MatveyVoiceCore", targets: ["MatveyVoiceCore"]),
        .executable(name: "MatveyVoice", targets: ["MatveyVoice"]),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "MatveyVoiceCore",
            dependencies: [.product(name: "WhisperKit", package: "WhisperKit")]
        ),
        .executableTarget(
            name: "MatveyVoice",
            dependencies: ["MatveyVoiceCore"]
        ),
        .testTarget(
            name: "MatveyVoiceCoreTests",
            dependencies: ["MatveyVoiceCore"]
        ),
    ]
)
