// swift-tools-version: 6.1
import PackageDescription

// MARK: - GameCore SPM パッケージ
//
// ar-tablebang-concentration の「プラットフォーム非依存な純ロジック」を切り出したパッケージ。
// ARKit / RealityKit / Vision / SwiftUI / CoreHaptics には依存せず、Foundation / Combine /
// CoreGraphics のみを使うため、フル Xcode が無い環境（Homebrew の swift 6.2.x ツールチェーン）でも
// `swift build` / `swift run GameCoreChecks` が動く。
//
// iOS フレームワーク依存のコード（VisionHandProvider, HUDView, ResultView, FeedbackController,
// 各 Combine/ObservableObject アダプタなど）は `TableBangConcentration/` 配下にソースとして置き、
// このパッケージではビルドしない。それらは kyiku 担当の Xcode プロジェクト（issue #10）と実機で検証する。
//
// テストについて:
//   この環境の Swift ツールチェーンには XCTest が同梱されていない（XCTest は通常 Xcode 専用）。
//   そのため検証は XCTest ではなく、実行可能ターゲット `GameCoreChecks`（自前アサート）で行い、
//   `swift run GameCoreChecks` で実際にロジックを実行して緑を確認する。
//   XCTest 版テストは Xcode のアプリ用テストターゲット（TableBangConcentration 側）に別途用意する。
let package = Package(
    name: "GameCore",
    platforms: [
        .macOS(.v12),
        .iOS(.v16)
    ],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
        .executable(name: "GameCoreChecks", targets: ["GameCoreChecks"])
    ],
    targets: [
        .target(
            name: "GameCore",
            path: "Sources/GameCore"
        ),
        .executableTarget(
            name: "GameCoreChecks",
            dependencies: ["GameCore"],
            path: "Sources/GameCoreChecks"
        )
    ]
)
