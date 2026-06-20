#if canImport(Vision) && canImport(UIKit)
import Combine
import CoreGraphics
import CoreVideo
import Foundation
import GameCore
import UIKit
import Vision

/// Apple Vision（`VNDetectHumanHandPoseRequest`）で `ARFrame.capturedImage`(CVPixelBuffer) から
/// 手の代表点（中指MCP＝手のひら中心相当）を検出し、`HandSample` として供給する `HandLandmarkProvider` 実装。
///
/// 設計対応: design.md `VisionHandProvider`。要件 3.1, 3.4, 3.5, 10.1, 10.6。research.md §1〜3。
///
/// 重要な実装方針（research.md）:
/// - 推論は専用シリアルキュー（`.userInitiated`）で実行し、ARKit の `session(_:didUpdate:)` は
///   「起動するだけ」にする。
/// - `isProcessing` フラグで前フレーム処理中はスキップ（= 自然な間引き）。台パン検出は実効15〜30fpsで十分。
/// - `CVPixelBuffer` は保持し続けず、推論完了後に速やかに解放（ARKit のバッファプール枯渇を防ぐ）。
/// - confidence がしきい値未満の点は破棄し「未検出」とする（= そのフレームでは発行しない）。
/// - 出力 `screenPoint` は左上原点・正規化 [0,1]。Vision の正規化座標（左下原点）から y を反転する。
///
/// - Note: この型は iOS フレームワーク（Vision/CoreVideo/UIKit）依存のため、本リポジトリの
///   GameCore SPM ビルドには含めない。kyiku の Xcode プロジェクト（#10）で実機検証する。
public final class VisionHandProvider: HandLandmarkProvider {

    // MARK: - HandLandmarkProvider

    public var samples: AnyPublisher<HandSample, Never> {
        subject.eraseToAnyPublisher()
    }

    // MARK: - 設定

    /// この信頼度未満の代表点は未検出として破棄する。
    public var confidenceThreshold: Float

    // MARK: - 内部状態

    private let subject = PassthroughSubject<HandSample, Never>()
    private let visionQueue = DispatchQueue(label: "VisionHandProvider.inference", qos: .userInitiated)
    private let request: VNDetectHumanHandPoseRequest

    /// 前フレームの推論が走っている間は新規フレームをスキップするための in-flight ガード。
    /// `visionQueue` 上でのみ読み書きする。
    private var isProcessing = false

    public init(confidenceThreshold: Float = 0.3) {
        self.confidenceThreshold = confidenceThreshold
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1  // 片手持ち・片手で台パンの MVP 前提
        self.request = request
    }

    // MARK: - フレーム供給

    /// `ARFrame.capturedImage`（CVPixelBuffer）を1フレーム分処理する。
    /// ARKit 非依存にするため `ARFrame` ではなく素の CVPixelBuffer ＋ タイムスタンプを受け取る。
    /// 呼び出し側（ARSceneController）は `frame.capturedImage` と `frame.timestamp` を渡す。
    ///
    /// - Parameters:
    ///   - pixelBuffer: カメラ画像（センサ向き）。
    ///   - timestamp: フレーム時刻（秒）。速度算出の Δt はこの実測値から求める。
    ///   - interfaceOrientation: 現在の画面向き（画像 orientation 補正に使う）。
    public func process(
        pixelBuffer: CVPixelBuffer,
        timestamp: TimeInterval,
        interfaceOrientation: UIInterfaceOrientation
    ) {
        // 前フレーム処理中なら間引く。
        var shouldRun = false
        visionQueue.sync {
            if !isProcessing {
                isProcessing = true
                shouldRun = true
            }
        }
        guard shouldRun else { return }

        let orientation = CameraOrientation.forCapturedImage(interfaceOrientation: interfaceOrientation)

        visionQueue.async { [weak self] in
            guard let self else { return }
            // どの経路で抜けても必ず in-flight を解除（キュー詰まり防止）。design.md Error Handling。
            defer { self.isProcessing = false }

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            do {
                try handler.perform([self.request])
            } catch {
                // 当該フレームを破棄して次フレームへ（クラッシュさせない）。
                return
            }

            guard let observation = self.request.results?.first else { return }

            // 代表点は中指MCP（手のひら中心相当、指の開閉ノイズに強い）。research.md §2。
            guard let point = try? observation.recognizedPoint(.middleMCP) else { return }
            guard point.confidence >= self.confidenceThreshold else { return }

            // Vision 正規化座標は左下原点 → 画面座標（左上原点）へ y 反転。
            let screenPoint = CGPoint(x: point.location.x, y: 1.0 - point.location.y)

            let sample = HandSample(
                screenPoint: screenPoint,
                timestamp: timestamp,
                confidence: point.confidence
            )
            self.subject.send(sample)
        }
    }
}
#endif
