# 台パン神経衰弱 — Web 版（埋め込み用）

ネイティブ iOS 版のゲームロジックを TypeScript へ移植し、**フレームワーク非依存の Web Component** として
埋め込めるようにしたパッケージ。サーバー不要のクライアントサイド完結（≒ ドロップイン部品）。

- 描画: 2D Canvas（iPhone Safari 含め全ブラウザで動作。WebXR 不要）
- 入力: ポインタ（マウス/タッチ）の下方向フリック＝台パン（速いほど高威力）
- ルール: 標準52枚（13ランク×4スート）、ペア＝同ランク＋同色（26ペア）、ターン制（全ペアでクリア）
- ランタイム依存ゼロ（`dist/table-bang.js` 約 4.6KB gzip）

## 開発・確認

```sh
cd web
npm install
npm run dev      # デモを起動（ブラウザで下方向フリック＝台パン）
npm test         # 純ロジックのユニットテスト（vitest）
npm run build    # dist/table-bang.js（埋め込み用 ES モジュール）を生成
```

## 埋め込み方

### 1. Web Component（どの TS フレームワークでも）

```html
<script type="module" src="/path/to/table-bang.js"></script>
<table-bang-game style="width:100%;height:70vh"></table-bang-game>
```

`import` するだけで `<table-bang-game>` が自動登録される:

```ts
import "table-bang-concentration";
```

React / Vue / Svelte でもそのまま `<table-bang-game />`（カスタム要素）として配置可能。

### 2. マウント関数（明示的に差し込む）

```ts
import { mountTableBangGame } from "table-bang-concentration";

mountTableBangGame(document.getElementById("game")!);
```

### 3. ロジックだけ再利用（自前の描画に組み込む）

AR や独自レンダラに組み込みたい場合、純ロジックを直接使える:

```ts
import { Game, defaultConfig } from "table-bang-concentration";

const game = new Game(defaultConfig);
game.start();
const result = game.bang({ x: 0.5, y: 0.5 }, /* peakVelocity */ 4.0);
// result.flipped / result.matched / game.state.turns / game.state.score / game.state.phase
```

## 構成

```
web/src/
  core/            # 純ロジック（AR非依存・テスト済み。ネイティブ版から移植）
    deck.ts            # 52枚・スート・matchKey（同ランク＋同色）
    matchEvaluator.ts  # ペア検出
    powerCalculator.ts # ピーク速度→威力
    shockwave.ts       # 影響半径・距離減衰
    swingDetector.ts   # 振り下ろし→台パン成立（ギャップ着地・クールダウン）
    gameState.ts       # スコア/コンボ/ターン/勝敗（ターン制）
    game.ts            # 盤面＋bang→めくれ→ペア回収のオーケストレータ
  component.ts     # <table-bang-game> Web Component（Canvas描画＋ポインタ入力）
  index.ts         # 公開API（自動登録）
```

## ネイティブ版との違い・制限

- **真の AR（机に固定）は非対応**。iPhone Safari は WebXR(immersive-ar) 未対応のため。本 Web 版は仮想盤面＋ポインタ操作。
- **LiDAR 深度による実速度補正なし**。威力はポインタ速度の正規化値ベース。
- カメラ＋手検出（MediaPipe Hands）での「実際の手で台パン」は将来の拡張ポイント（`SwingDetector` にそのまま接続可能な設計）。

## 移植の対応関係（ネイティブ → Web）

| ネイティブ(Swift) | Web(TS) |
|---|---|
| `DeckFactory`/`Suit`/`Card` | `core/deck.ts` |
| `MatchEvaluator` | `core/matchEvaluator.ts` |
| `PowerCalculator` | `core/powerCalculator.ts` |
| `Shockwave` | `core/shockwave.ts` |
| `HandSwingDetector` | `core/swingDetector.ts` |
| `GameStateManager` | `core/gameState.ts` |
| `CardManager`+`ShockwaveSystem`+`GameSession` | `core/game.ts` |
| ARKit/RealityKit/Vision | 2D Canvas ＋ ポインタ入力（`component.ts`） |
