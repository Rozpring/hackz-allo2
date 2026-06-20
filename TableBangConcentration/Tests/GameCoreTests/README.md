# GameCore ユニットテスト（XCTest / Xcode 用）

issue #33（tasks 9.1）の成果物。これらは **Xcode のアプリ用テストターゲット**で実行する XCTest。
GameCore を SPM 依存として参照する。

## 実行可能な等価スイート

この開発機にはフル Xcode（＝XCTest）が無いため、同じシナリオを**実行可能な**形でも用意している:

```sh
/opt/homebrew/opt/swift/bin/swift run GameCoreChecks
```

`GameCoreChecks` は本 XCTest と同等の検証を自前アサートで行い、CI/手動で緑を確認済み。
（本 XCTest は Xcode 取り込み後に同じく緑になることを想定。）

## カバレッジ

| 対象 | 担当 | 状態 |
|------|------|------|
| HandSwingDetector（台パン成立判定, 4.3） | 自分 #21 | ✅ 本スイート + GameCoreChecks |
| PowerCalculator（威力正規化, 4.2/4.3） | 自分 #22 | ✅ 本スイート + GameCoreChecks |
| MatchEvaluator（ペア検出, 6.1） | 自分 #25 | ✅ 本スイート + GameCoreChecks |
| GameStateManager（スコア/コンボ/進行, 6.2） | 自分 #26 | ✅ GameCoreChecks（XCTest版は #34 統合と合わせて拡充可） |
| DeckFactory 不変条件（各ランク2枚, 2.3/2.4） | kyiku #17 | ⏳ **未実装依存**。#17 完了後に追加 |
| ShockwaveSystem 距離減衰の純関数（5.2/5.3） | kyiku #23 | ⏳ **未実装依存**。#23 で純関数部を抽出後に追加 |

> デッキ不変条件・衝撃波減衰のテストは、対象モジュール（kyiku 担当 #17 / #23）が未実装のため本 PR では未着手。
> モジュール到着後にここへ追加する。
