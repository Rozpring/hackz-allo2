# 台パン神経衰弱 — Web 版（埋め込み用）

ネイティブ iOS 版のゲームロジックを TypeScript へ移植し、**フレームワーク非依存の Web Component** として
埋め込めるようにしたパッケージ。サーバー不要のクライアントサイド完結（≒ ドロップイン部品）。

- 描画/物理: **three.js（3D）＋ cannon-es（物理エンジン）**。台パンでカードが物理で跳ねてめくれる（ネイティブに近い見た目）
- 入力: ポインタ（マウス/タッチ）の下方向フリック＝台パン（速いほど広く飛ぶ）
- ルール: 標準52枚（13ランク×4スート）、ペア＝同ランク＋同色（26ペア）、ターン制（全ペアでクリア）
- iPhone Safari 含め全ブラウザで動作（WebGL。WebXR 不要）。バンドル ≈ 171KB gzip（three/cannon 同梱）

## 開発・確認

```sh
cd web
npm install
npm run dev          # PCブラウザで確認（https://localhost:5173、証明書警告は許可）
npm run dev:phone    # スマホ実機で確認（https://<PCのLAN IP>:5173 を開く。証明書警告→許可）
npm test             # 純ロジックのユニットテスト（vitest）
npm run build        # dist/table-bang.js（埋め込み用 ES モジュール）を生成
```

### スマホのカメラで「実際の手で台パン」

画面右上の **「📷 カメラで台パン」** を押すと、カメラ映像を背景に MediaPipe Hands で手を検出し、
**実際に手を振り下ろす＝台パン**になります（手のランドマーク → `SwingDetector`）。

- **HTTPS 必須**: `getUserMedia` はセキュアコンテキストが必要。`npm run dev`/`dev:phone` は自己署名 https で起動する。
  スマホは PC と同じ Wi‑Fi で `https://<PCのLAN IP>:5173` を開き、証明書警告を許可 → カメラ許可。
- MediaPipe の wasm/モデルは CDN（jsdelivr / googleapis）から実行時ロード（オフライン不可）。
- カメラが使えない/拒否時は自動でポインタ操作にフォールバック。

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
    game.ts            # ヘッドレス/2D 用の決定論オーケストレータ（テスト・ロジック再利用向け）
  render3d/
    scene3d.ts         # three.js 描画＋cannon-es 物理（衝撃波インパルス・静止検出・表裏確定・ペア回収）
    cardTexture.ts     # ランク＋スートの表/裏テクスチャ生成
  input/
    handCamera.ts      # getUserMedia + MediaPipe Hands（手の代表点→SwingDetector）
  component.ts     # <table-bang-game> Web Component（3Dシーン＋ポインタ/カメラ手検出入力）
  index.ts         # 公開API（自動登録）
```

## ネイティブ版との違い・制限

- **3D＋物理エンジンでネイティブに近い見た目**（カードが跳ねて回転してめくれる）。ただし RealityKit ではなく three.js+cannon-es による独自実装。
- **真の AR（机に固定）は非対応**。iPhone Safari は WebXR(immersive-ar) 未対応のため。本 Web 版は固定カメラの仮想盤面＋ポインタ操作。
- **カメラ＋手検出（MediaPipe Hands）対応済み**。実際の手で台パンできる（iPhone Safari 含む。HTTPS 必須）。ただし 2D ランドマークのため LiDAR のような実距離（高さ）補正はなし。
- **LiDAR 深度による実速度補正なし**。威力はポインタ/手の画面速度の正規化値ベース。
- 物理係数（影響半径・インパルス・減衰・静止しきい値）は `scene3d.ts` 冒頭の定数で調整可能（実機/各端末でチューニング前提）。

## 移植の対応関係（ネイティブ → Web）

| ネイティブ(Swift) | Web(TS) |
|---|---|
| `DeckFactory`/`Suit`/`Card` | `core/deck.ts` |
| `MatchEvaluator` | `core/matchEvaluator.ts` |
| `PowerCalculator` | `core/powerCalculator.ts` |
| `Shockwave` | `core/shockwave.ts` |
| `HandSwingDetector` | `core/swingDetector.ts` |
| `GameStateManager` | `core/gameState.ts` |
| `CardManager`+`ShockwaveSystem`+`PhysicsSettleObserver` | `render3d/scene3d.ts`（3D物理） / `core/game.ts`（ヘッドレス2D） |
| `CardEntity`/`CardFace` | `render3d/scene3d.ts` + `render3d/cardTexture.ts` |
| RealityKit（描画・物理） | three.js（描画）＋ cannon-es（物理） |
| Vision（手検出） | MediaPipe Hands（`input/handCamera.ts`） |
| ARKit（ワールドトラッキング） | 固定カメラの仮想盤面（背景にカメラ映像） |
| `VisionHandProvider`→`HandSwingDetector` | `handCamera.ts`→`SwingDetector`（同じ接続） |
