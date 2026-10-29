// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "MinionChess",
    platforms: [.macOS(.v13)],
    targets: [.executableTarget(name: "MinionChess", path: "Sources/MinionChess")]
)
