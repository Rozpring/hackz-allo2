import Combine
import Foundation

/// テスト・プレビュー用の `HandLandmarkProvider` モック実装。
///
/// 任意の `HandSample` 列を手動で、あるいは時系列としてまとめて発行できる。
/// 実機・Vision を介さずに `HandSwingDetector` や Input 連鎖の単体/結合テストを可能にする。
///
/// - 設計対応: tasks.md 4.1 完了条件「モック実装で任意の代表点列を発行でき、購読側が受信できる」。
public final class MockHandLandmarkProvider: HandLandmarkProvider {
    private let subject = PassthroughSubject<HandSample, Never>()

    public init() {}

    public var samples: AnyPublisher<HandSample, Never> {
        subject.eraseToAnyPublisher()
    }

    /// 単一サンプルを発行する。
    public func emit(_ sample: HandSample) {
        subject.send(sample)
    }

    /// 複数サンプルを順に発行する。
    public func emit(_ samples: [HandSample]) {
        for sample in samples {
            subject.send(sample)
        }
    }

    /// 等間隔の時系列サンプルを組み立てて発行するヘルパ。
    /// - Parameters:
    ///   - yPositions: 代表点の y 座標列（左上原点なので下方向が増加）。
    ///   - x: 全サンプル共通の x 座標。
    ///   - startTime: 先頭サンプルの時刻。
    ///   - interval: サンプル間隔（Δt）。
    ///   - confidence: 全サンプル共通の信頼度。
    public func emitSeries(
        yPositions: [CGFloat],
        x: CGFloat = 0.5,
        startTime: TimeInterval = 0,
        interval: TimeInterval = 1.0 / 30.0,
        confidence: Float = 0.9
    ) {
        for (index, y) in yPositions.enumerated() {
            subject.send(
                HandSample(
                    screenPoint: CGPoint(x: x, y: y),
                    timestamp: startTime + interval * Double(index),
                    confidence: confidence
                )
            )
        }
    }
}
