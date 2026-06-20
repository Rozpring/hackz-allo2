import CoreGraphics
import Foundation

/// 手検出器が供給する「手の代表点」1サンプル。
///
/// - Note: 画面座標は左上原点（UIKit 系）に正規化済みであることを前提とする。
///   Vision の正規化座標（左下原点）からの y 反転は `VisionHandProvider`（iOS 側, issue #20）が行う。
/// - 設計対応: design.md `HandSample`（Input Layer）。要件 3.1, 3.2。
public struct HandSample: Equatable, Sendable {
    /// 手の代表点（中指MCP相当）の画面座標。左上原点。
    public let screenPoint: CGPoint
    /// このサンプルが取得された時刻（秒）。速度算出の Δt は必ずこの実測値から求める。
    public let timestamp: TimeInterval
    /// 検出信頼度 [0,1]。供給側で閾値フィルタ済みであることが望ましい。
    public let confidence: Float

    public init(screenPoint: CGPoint, timestamp: TimeInterval, confidence: Float) {
        self.screenPoint = screenPoint
        self.timestamp = timestamp
        self.confidence = confidence
    }
}
