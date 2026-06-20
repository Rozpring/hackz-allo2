import Combine
import CoreGraphics
import CoreVideo
import Foundation
import UIKit
import Vision
import ARKit

/// Apple Vision（`VNDetectHumanHandPoseRequest`）で `ARFrame.capturedImage`(CVPixelBuffer) から
/// 手の代表点（中指MCP＝手のひら中心相当）を検出し、`HandSample` として供給する `HandLandmarkProvider` 実装。
///
/// 設計対応: design.md `VisionHandProvider`。要件 3.1, 3.4, 3.5, 10.1, 10.6。research.md §1〜3。
///
/// 実装方針（research.md）:
/// - 推論は専用シリアルキュー（`.userInitiated`）で実行し、ARKit のデリゲートは「起動するだけ」にする。
/// - `isProcessing` フラグで前フレーム処理中はスキップ（= 自然な間引き）。実効15〜30fpsで台パン検出に十分。
/// - `CVPixelBuffer` は保持し続けず、推論完了後に速やかに解放（ARKit のバッファプール枯渇を防ぐ）。
/// - confidence がしきい値未満の点は破棄し「未検出」とする（= そのフレームでは発行しない）。
/// - 出力 `screenPoint` は左上原点・正規化 [0,1]。Vision の正規化座標（左下原点）から y を反転する。
final class VisionHandProvider: HandLandmarkProvider {
    var samples: AnyPublisher<HandSample, Never> { subject.eraseToAnyPublisher() }

    /// この信頼度未満の代表点は未検出として破棄する。
    var confidenceThreshold: Float

    private let subject = PassthroughSubject<HandSample, Never>()
    private let visionQueue = DispatchQueue(label: "VisionHandProvider.inference", qos: .userInitiated)
    private let request: VNDetectHumanHandPoseRequest

    /// 前フレームの推論中は新規フレームをスキップする in-flight ガード（`visionQueue` 上でのみ読み書き）。
    private var isProcessing = false

    init(confidenceThreshold: Float = 0.2) {
        self.confidenceThreshold = confidenceThreshold
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1 // 片手持ち・片手で台パンの MVP 前提
        self.request = request
    }

    /// `HandLandmarkProvider`: ARFrame から capturedImage・timestamp・LiDAR深度を取り出して推論へ渡す。
    func process(frame: ARFrame, interfaceOrientation: UIInterfaceOrientation) {
        process(
            pixelBuffer: frame.capturedImage,
            timestamp: frame.timestamp,
            interfaceOrientation: interfaceOrientation,
            depthMap: frame.smoothedSceneDepth?.depthMap ?? frame.sceneDepth?.depthMap
        )
    }

    /// ARKit 非依存の推論本体（テスト/差し替えのため CVPixelBuffer ＋ タイムスタンプで受ける）。
    func process(
        pixelBuffer: CVPixelBuffer,
        timestamp: TimeInterval,
        interfaceOrientation: UIInterfaceOrientation,
        depthMap: CVPixelBuffer? = nil
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

        // 画像 orientation 補正は CoordinateMath に集約（#12）。
        let orientation = CoordinateMath.imageOrientation(for: interfaceOrientation)

        visionQueue.async { [weak self] in
            guard let self else { return }
            // どの経路でも必ず in-flight を解除（キュー詰まり防止）。
            defer { self.isProcessing = false }

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            do {
                try handler.perform([self.request])
            } catch {
                return // 当該フレームを破棄して次フレームへ（クラッシュさせない）。
            }

            guard let observation = self.request.results?.first else { return }
            // 代表点は中指MCP（手のひら中心相当、指の開閉ノイズに強い）。research.md §2。
            guard let point = try? observation.recognizedPoint(.middleMCP) else { return }
            guard point.confidence >= self.confidenceThreshold else { return }

            // Vision 正規化座標は左下原点 → 画面座標（左上原点）へ y 反転。
            let screenPoint = CoordinateMath.flipY(point.location)
            let depth = depthMap.flatMap { Self.sampleNearestDepth(in: $0, visionPoint: point.location) }
            let sample = HandSample(
                screenPoint: screenPoint,
                timestamp: timestamp,
                confidence: point.confidence,
                depth: depth
            )
            self.subject.send(sample)
        }
    }

    /// 深度マップ（LiDAR, Float32メートル）から手の距離を推定する。
    /// 手は台パン中カメラ前方の最も近い物体になりやすいため、推定点まわりの窓内の「最も近い有効深度」を採る。
    /// これにより Vision座標→深度マップ座標の厳密な向き合わせがズレても、手の距離を拾いやすくする。
    static func sampleNearestDepth(in depthMap: CVPixelBuffer, visionPoint: CGPoint) -> Float? {
        guard CVPixelBufferGetPixelFormatType(depthMap) == kCVPixelFormatType_DepthFloat32 else { return nil }
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return nil }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)

        // Vision 正規化点（左下原点）を深度マップ（センサ＝横長）座標へおおまかに対応付ける。
        // 厳密な向き補正は実機チューニングの対象。窓内最小で誤差を吸収する。
        let cx = Int(min(max(visionPoint.y, 0), 1) * CGFloat(width - 1))
        let cy = Int(min(max(1 - visionPoint.x, 0), 1) * CGFloat(height - 1))
        let radius = max(4, width / 12)

        var nearest: Float = .greatestFiniteMagnitude
        var y = max(0, cy - radius)
        while y <= min(height - 1, cy + radius) {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float32.self)
            var x = max(0, cx - radius)
            while x <= min(width - 1, cx + radius) {
                let d = row[x]
                if d.isFinite, d > 0.1, d < 5.0, d < nearest { nearest = d }
                x += 1
            }
            y += 1
        }
        return nearest < .greatestFiniteMagnitude ? nearest : nil
    }
}
