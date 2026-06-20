# ar-tablebang-concentration

台パン（テーブルを手で叩く動作）で神経衰弱を遊ぶ AR ゲームの iOS MVP。
仕様は [`.kiro/specs/ar-tablebang-concentration/`](.kiro/specs/ar-tablebang-concentration/) を参照。

## コード構成

このリポジトリは2つのソースツリーに分かれている。

### 1. `Sources/GameCore/` — プラットフォーム非依存の純ロジック（SPM パッケージ）

ARKit / RealityKit / Vision / SwiftUI / CoreHaptics に依存せず、Foundation / Combine /
CoreGraphics のみを使うロジック層（手の振り下ろし速度算出・威力正規化・ペア検出・スコア/進行など）。
フル Xcode が無くても `swift build` で検証でき、CI に載せやすい。

担当 issue: #19 (4.1), #21 (4.3), #22 (4.4), #25 (6.1), #26 (6.2) のロジック部分。

### 2. `TableBangConcentration/` — iOS アプリ（kyiku の Xcode プロジェクト #10 に取り込む想定）

ARKit / RealityKit / Vision / SwiftUI / CoreHaptics 依存のコード（Vision 手検出・HUD・結果画面・
触覚/効果音、および GameCore を Combine/ObservableObject でラップするアダプタ）。
**この層はフル Xcode と実機が必要で、本リポジトリの SPM ビルドには含めない。**

将来 kyiku の Xcode プロジェクトから `Sources/GameCore` をローカル SPM 依存として取り込めば、
純ロジックを単一の真実として共有できる。

## ビルドとテスト

### ツールチェーン（重要）

この開発機にはフル Xcode が無く、同梱の Command Line Tools（Swift 6.1.2）は SwiftPM マニフェストと
SDK の不整合でビルド不可。そのため **Homebrew の Swift 6.2.x ツールチェーン**を使う。

```sh
brew install swift           # /opt/homebrew/opt/swift/Swift-6.2.xctoolchain に入る
```

`~/.zshenv` に以下を設定済み（非対話 shell でも有効）:

```sh
export PATH="/opt/homebrew/opt/swift/bin:$PATH"
export SDKROOT="$(/usr/bin/xcrun --show-sdk-path)"   # macOS SDK
```

macOS の `path_helper` が `/usr/bin` を PATH 先頭へ戻すため、コマンドは brew swift を**絶対パス**で叩くのが確実:

```sh
/opt/homebrew/opt/swift/bin/swift build
```

### ロジックの検証（XCTest の代替）

この環境の Swift ツールチェーンには XCTest が同梱されていない（XCTest は通常 Xcode 専用）。
そのため検証は実行可能ターゲット **`GameCoreChecks`**（自前アサート）で行い、実際にロジックを動かして緑を確認する。

```sh
/opt/homebrew/opt/swift/bin/swift run GameCoreChecks
```

失敗が1件でもあればプロセスは非0で終了する。XCTest 版テストは Xcode のアプリ用テストターゲット
（`TableBangConcentration` 側）に別途用意し、実機/シミュレータで実行する。
