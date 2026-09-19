// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "FocusBar",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "FocusBar", targets: ["FocusBar"])],
  targets: [
    .target(name: "FocusCore"),
    .executableTarget(
      name: "FocusBar", dependencies: ["FocusCore"],
      swiftSettings: [
        .defaultIsolation(MainActor.self),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
      ]),
    .executableTarget(
      name: "FocusCoreChecks", dependencies: ["FocusCore"], path: "Tests/FocusCoreTests"),
  ]
)
