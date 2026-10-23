// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pause",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Pause", targets: ["RestApp"])],
    dependencies: [.package(url:"https://github.com/sparkle-project/Sparkle",exact:"2.10.0")],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "RestCore"),
        .target(name: "RestStorage", dependencies: ["RestCore", "CSQLite"]),
        .executableTarget(name: "RestApp", dependencies: ["RestCore", "RestStorage", .product(name:"Sparkle",package:"Sparkle")]),
        .testTarget(name: "RestCoreTests", dependencies: ["RestCore", "RestStorage", "CSQLite"])
    ]
)
