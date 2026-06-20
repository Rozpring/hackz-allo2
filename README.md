# 台パン神経衰弱（AR Table-Bang Concentration）

台パン（テーブルを手で叩く動作）で遊ぶ AR 神経衰弱ゲーム。iPhone のカメラ越しに AR でトランプを伏せて配置し、空いた手で台パンすると、その振り下ろし速度が威力となり、衝撃波でカードが物理的に跳ねてめくれる。表になった同じ数字のペアが自動成立して消えていく。

iOS ネイティブ（Swift + ARKit + RealityKit + Vision）。MVP はシングルプレイ・片手持ち・タイムアタック。

## 必要環境

- macOS + Xcode 16 以降（iOS 16+ ターゲット）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
  ```sh
  brew install xcodegen
  ```

## セットアップ

`.xcodeproj` は Git 管理せず、`project.yml` から生成する方針です。クローン後に必ず生成してください。

```sh
xcodegen generate
open TableBangConcentration.xcodeproj
```

`project.yml` を変更したら、再度 `xcodegen generate` を実行します。

## ビルド / テスト（CLI）

```sh
# ユニットテスト（シミュレータ）
xcodebuild test \
  -project TableBangConcentration.xcodeproj \
  -scheme TableBangConcentration \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

> ARKit / Vision / RealityKit の実挙動（平面検出・手検出・物理）は **実機**が必要です。シミュレータではビルド検証とロジックのユニットテストまでを行います。

## ディレクトリ構成

```
TableBangConcentration/
├── App/        # エントリ・画面遷移
├── AR/         # ARセッション・平面検出・raycast（実装予定）
├── Cards/      # カードエンティティ・デッキ・盤面
├── Input/      # 手検出（Vision）・振り下ろし速度・威力算出
├── Physics/    # 衝撃波インパルス・静止検出（実装予定）
├── Game/       # ペア判定・スコア/コンボ・進行・GameConfig
├── UI/         # HUD・結果画面（実装予定）
├── Feedback/   # 触覚・効果音（実装予定）
└── Support/    # イベント型・座標変換ヘルパ
Tests/          # ユニットテスト
```

## 仕様（Spec-Driven Development）

要件・設計・タスクは `.kiro/specs/ar-tablebang-concentration/` にあります（`requirements.md` / `design.md` / `tasks.md` / `research.md`）。実装タスクは GitHub Issues（`MVP` マイルストーン）で管理しています。
