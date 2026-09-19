// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "SitLess",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "SitLess", targets: ["SitLess"])],
  targets: [
    .target(name: "FocusCore"),
    .executableTarget(
      name: "SitLess", dependencies: ["FocusCore"],
      swiftSettings: [
        .defaultIsolation(MainActor.self),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
      ]),
    .executableTarget(
      name: "FocusCoreChecks", dependencies: ["FocusCore"], path: "Tests/FocusCoreTests"),
  ]
)
