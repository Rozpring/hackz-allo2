import ARKit
import Combine
import CoreGraphics
import CoreVideo
import Foundation
import UIKit
import Vision

/// Apple Vision（`VNDetectHumanHandPoseRequest`）で `ARFrame.capturedImage` から手の代表点
/// （中指MCP＝手のひら中心相当）を検出し、`HandSample` として供給する `HandLandmarkProvider` 実装。
///
/// 設計対応: design.md `VisionHandProvider`。要件 3.1, 3.4, 3.5, 10.1, 10.6。research.md §1〜3。
///
/// 実装方針（research.md）:
/// - 推論は専用シリアルキュー（`.userInitiated`）で実行（`session(_:didUpdate:)` は起動するだけ）。
/// - `isProcessing` フラグで前フレーム処理中はスキップ（自然な間引き）。台パン検出は実効15〜30fpsで十分。
/// - confidence がしきい値未満の点は破棄＝そのフレームでは発行しない（未検出扱い）。
/// - 端末向き補正・y反転は `CoordinateMath`（既存ヘルパ）を用いる。出力 `screenPoint` は左上原点・正規化。
/// - カメラ映像は端末外へ送信しない（R10-6）。
///
/// `HandLandmarkProvider` に注入して `GameSession` から使う想定（現状 main は Vision 実装を欠く）。
final class VisionHandProvider: HandLandmarkProvider {

    /// この信頼度未満の代表点は未検出として破棄する。
    var confidenceThreshold: Float

    var samples: AnyPublisher<HandSample, Never> {
        subject.eraseToAnyPublisher()
    }

    private let subject = PassthroughSubject<HandSample, Never>()
    private let visionQueue = DispatchQueue(label: "VisionHandProvider.inference", qos: .userInitiated)
    private let request: VNDetectHumanHandPoseRequest

    /// `visionQueue` 上でのみ読み書きする in-flight ガード。
    private var isProcessing = false

    init(confidenceThreshold: Float = 0.3) {
        self.confidenceThreshold = confidenceThreshold
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1  // 片手持ち・片手で台パンの MVP 前提
        self.request = request
    }

    /// `ARFrame` を1フレーム分処理する（`HandLandmarkProvider` 契約）。
    /// 前フレーム処理中はスキップ（間引き）。`capturedImage`/`timestamp` を取り出して推論する。
    func process(frame: ARFrame, interfaceOrientation: UIInterfaceOrientation) {
        var shouldRun = false
        visionQueue.sync {
            if !isProcessing {
                isProcessing = true
                shouldRun = true
            }
        }
        guard shouldRun else { return }

        let pixelBuffer = frame.capturedImage
        let timestamp = frame.timestamp
        let orientation = CoordinateMath.imageOrientation(for: interfaceOrientation)

        visionQueue.async { [weak self] in
            guard let self else { return }
            // どの経路で抜けても必ず in-flight を解除（キュー詰まり防止）。
            defer { self.isProcessing = false }

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            do {
                try handler.perform([self.request])
            } catch {
                return  // 当該フレームを破棄して次フレームへ（クラッシュさせない）
            }

            guard let observation = self.request.results?.first else { return }
            guard let point = try? observation.recognizedPoint(.middleMCP) else { return }
            guard point.confidence >= self.confidenceThreshold else { return }

            // Vision 正規化座標（左下原点）→ 画面座標（左上原点）へ y 反転（既存ヘルパを使用）。
            let screenPoint = CoordinateMath.flipY(point.location)

            let sample = HandSample(
                screenPoint: screenPoint,
                timestamp: timestamp,
                confidence: point.confidence
            )
            self.subject.send(sample)
        }
    }
}
