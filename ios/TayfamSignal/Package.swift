// swift-tools-version:5.9

// Tayfam'ın iOS Signal katmanı (istemci ADR-0010, ADR-0034 §7).
//
// Signal'in resmi Swift paketi `LibSignalClient` ve onun Rust çekirdeğinin
// Signal'in yayımladığı hazır XCFramework'ü. İkisi aynı sürümde olmalıdır;
// sürüm ve sağlama toplamı Signal-iOS'un kendi `BinaryDependencies`
// manifestindeki değerlerdir (libsignal v0.108.1, commit 8bb22ec). SPM
// indirilen arşivi bu toplamla doğrular. Sürüm yükseltilirken ikisi
// birlikte değişir ve `Package.resolved` yenilenir.
//
// Lisans: libsignal AGPL-3.0'dır. App Store dağıtımı için ek izin yoktur;
// platform sahibi riski 2026-11-27'de kabul etti (ADR-0034, "Kararlar").

import PackageDescription

let package = Package(
  name: "TayfamSignal",
  platforms: [.iOS(.v15)],
  products: [
    .library(name: "TayfamSignal", targets: ["TayfamSignal"])
  ],
  dependencies: [
    .package(url: "https://github.com/signalapp/libsignal", exact: "0.108.1")
  ],
  targets: [
    .binaryTarget(
      name: "LibSignalFfi",
      url:
        "https://build-artifacts.signal.org/libraries/libsignal-client-ios-build-v0.108.1.xcframework.zip",
      checksum: "1a1ebf8b50a9f885ae0d336b1aaa5d0d1b984794ef9280b20df11c3156a896cb"
    ),
    .target(
      name: "TayfamSignal",
      dependencies: [
        .product(name: "LibSignalClient", package: "libsignal"),
        "LibSignalFfi",
      ]
    ),
    .testTarget(
      name: "TayfamSignalTests",
      dependencies: ["TayfamSignal"]
    ),
  ]
)
