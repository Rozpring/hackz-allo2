# Research Log — ar-tablebang-concentration

## Discovery Scope
新規（greenfield）・複雑機能のため Full Discovery を実施。2軸を並列リサーチした。
1. iOS でカメラ映像から手のランドマークを検出し、振り下ろし速度を算出する方式。
2. ARKit と組み合わせてトランプに物理演算をさせる方式。

## Key Findings

### 1. 手検出: Apple Vision を採用（MediaPipe を退ける）
- **`VNDetectHumanHandPoseRequest`（Vision, iOS 14+）** は21点の手ランドマークを返し、`ARFrame.capturedImage`（CVPixelBuffer, YUV）を `VNImageRequestHandler(cvPixelBuffer:orientation:)` で**直接処理できる**。依存ゼロ（`import Vision` のみ）、ライセンス問題なし。
- **MediaPipe Tasks Vision HandLandmarker** は3D(z)・左右判定・高精度で優るが、**CocoaPods必須（SPM非対応）＋ `.task` モデル同梱**が必要でセットアップコストが高い。今回必要なのは2Dの手首/手のひらy座標のみのため過剰。
- **決定**: MVPは **Vision** を採用。3D速度や両手判定が必要になった時点で MediaPipe へ乗り換え可能（差し替え可能なインターフェースにする）。

### 2. 振り下ろし速度: 画面座標(2D)ベース近似で十分
- 代表点は **中指MCP（手のひら中心相当）** が指の開閉ノイズに強く推奨。手首(`.wrist`)でも可。
- y座標の時系列差分 `vy = (yₜ − yₜ₋₁) / Δt` でピーク速度を取得。下降の継続→急減速(反転)を「台パン成立（着地）」とみなす。
- **注意**: px/s（正規化/s）は**カメラと手の距離・画角に依存する相対量**で絶対速度ではない。MVPは相対しきい値で運用（キャリブレーション前提）。Δtは必ず実測。低confidence点は破棄、軽い平滑化（EMA / `VNSequenceRequestHandler`）推奨。
- **向きの罠**: `capturedImage` は常にセンサ向き（ランドスケープ固定）。`VNImageRequestHandler` の `orientation:` を端末向きから算出して渡す（ポートレート背面カメラは概ね `.right`）。Vision正規化座標は**左下原点**なので画面座標へはy反転。

### 3. パフォーマンス: 検出は別キュー＋in-flightガードで間引く
- ARKitの `session(_:didUpdate:)` では検出を**起動するだけ**にし、推論は `DispatchQueue(qos: .userInitiated)` で実行。
- `isProcessing` フラグで「前フレーム処理中はスキップ」＝自然なフレーム落とし。台パン検出は実効15〜30fpsで十分。
- `CVPixelBuffer` を保持し続けると ARKit のバッファプールが枯渇するので、検出側は速やかに解放/コピー。

### 4. AR＋物理: RealityKit を採用（SceneKit を退ける）
- **WWDC 2025 で SceneKit はソフトディプリケーション（保守モード・新機能なし）**と明言。Apple は新規ARに **RealityKit** を公式推奨。
- RealityKit の剛体物理（`PhysicsBodyComponent`, `PhysicsMaterialResource`, 重力・質量・摩擦・反発・インパルス・トルク）は本要件（平板カードの跳ね・回転・着地・表裏判定）に十分対応。
- ビューは **`ARView`（UIKit）** を採用。raycast/タップのサンプルが豊富でデバッグが速くMVP向き（SwiftUI統一なら iOS18+ `RealityView` も可）。

### 5. 物理の非決定論的ばらつきの作り方
- `applyImpulse(_:at:relativeTo:)` で**重心からオフセットした打点**に打つと並進＋回転が自然発生。
- これに `applyAngularImpulse` の**軸ランダムトルク**＋微小ランダム並進＋反発係数を組み合わせ、「浮くだけ／半回転反転／一回転で同面／複数回転」のばらつきを作る。
- 衝撃波は中心からの距離で減衰（`falloff = max(0, 1 - dist/radius)`）。

### 6. 静止検出・表裏判定
- 公開の `isSleeping` 相当APIは確認できず。**`PhysicsMotionComponent` の `linearVelocity`/`angularVelocity` をしきい値判定**し、数フレーム連続で静止とみなす（チャタリング防止）。
- 表/伏せは**カードのローカル+Y法線をワールド変換し、y成分の符号**で判定（`worldUp.y > 0` で表）。カードは表面=ローカル+Yで生成。

### 7. 配置・raycast・盤外防止
- `ARWorldTrackingConfiguration` + `.horizontal` で平面検出。タップ位置は `arView.raycast(from:allowing:.existingPlaneInfinite, alignment:.horizontal)` で平面へ投影。
- カードは `AnchorEntity(world:)` 配下に格子配置。**`.static` の床コライダー**を同アンカー下に置くと安定（生メッシュより確実）。
- 盤外飛び出し防止: 外周に `.static` の不可視壁、速度クランプ、インパルス上限、damping高めの併用。
- 負荷削減: 静止カードを `.static` に落とし、台パン時に `.dynamic` へ戻す疑似スリープ。コライダーは単純箱必須（メッシュは重い）。

## Architecture Decisions
| 決定 | 採用 | 理由 |
|------|------|------|
| 手検出 | Apple Vision `VNDetectHumanHandPoseRequest` | 依存ゼロ・ARFrame直結・MVP十分。差し替え可能に設計 |
| 速度算出 | 画面座標2D近似（中指MCP） | zなしでも台パン検出に十分。相対しきい値＋キャリブレーション |
| AR描画/物理 | RealityKit（`ARView`） | SceneKitは保守モード。AR統合・物理が一級 |
| カード挙動 | 物理インパルス（打点オフセット＋ランダムトルク） | 非決定論的ばらつきを自然に生成 |
| 静止/表裏 | velocityしきい値 + ワールド+Y符号 | 公開isSleeping無し。法線符号で確実 |

## Risks & Mitigations
- **R1: ARKitワールドトラッキング＋毎フレームVision＋16体物理で60fps割れ** → 検出間引き（in-flightガード）、単純箱コライダー、疑似スリープ、低ポリ。実機Instruments計測。
- **R2: 速度しきい値が端末/距離で変わる** → キャリブレーション値を外出しパラメータ化。プレイ開始前に軽い調整ステップを検討。
- **R3: 物理のばらつきが「理不尽」に感じられる** → インパルス・トルクのレンジを調整パラメータ化し体感チューニング。
- **R4: 手がフレーム外/低信頼度で誤検出** → confidenceフィルタ＋未検出時は台パン判定停止（要件R3-4, R4-6）。
- **R5: 片手持ちで端末が揺れARアンカーがずれる** → ワールドアンカー基準で固定、トラッキング品質低下時はガイド表示。

## Sources（主要）
- Vision Hand Pose: https://developer.apple.com/videos/play/wwdc2020/10653/ , https://www.createwithswift.com/detecting-hand-pose-with-the-vision-framework/
- MediaPipe HandLandmarker iOS: https://developers.google.com/edge/mediapipe/solutions/vision/hand_landmarker/ios
- ARFrame→Vision: https://developer.apple.com/forums/thread/665274
- SceneKit deprecation / RealityKit移行: https://dev.to/arshtechpro/wwdc-2025-scenekit-deprecation-and-realitykit-migration-a-comprehensive-guide-for-ios-developers-o26
- RealityKit PhysicsBodyComponent: https://developer.apple.com/documentation/realitykit/physicsbodycomponent
- PhysicsMotionComponent: https://developer.apple.com/documentation/realitykit/physicsmotioncomponent
- applyImpulse/applyAngularImpulse: https://developer.apple.com/forums/thread/735113 , https://developer.apple.com/documentation/realitykit/hasphysicsbody/applyangularimpulse(_:relativeto:)
- RealityKit physics 解説: https://markhorgan.com/blog/physics-in-realitykit/ , https://stepinto.vision/example-code/collisions-physics-getting-started-with-physics-body-component/
- raycast/配置: https://ethansaadia.medium.com/ray-casting-in-realitykit-9288be5c3e2c , https://coledennis.medium.com/tutorial-tap-to-place-ar-content-using-realitykit-and-swiftui-e2579d93708d
