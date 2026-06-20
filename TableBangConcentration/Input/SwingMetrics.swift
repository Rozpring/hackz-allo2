import Foundation
import CoreGraphics

/// 振り下ろし速度を実寸（m/s）へ換算する純関数。
///
/// 画面の正規化縦移動量だけでは、手の距離（高さ）が変わると同じ速さでも値がブレる。
/// LiDAR深度 `depth` を使い「その距離での実寸縦移動量」に換算してから速度にすることで、
/// 距離に依らず実際の振り下ろし速度を得る（威力が実速度どおりになる）。
enum SwingMetrics {
    /// 正規化縦移動量(Δy, 0..1) を実寸メートルの縦移動へ換算。
    /// 距離 `depth` における画面縦全体の実寸 ≒ `depth * depthToMetersFactor`（係数 ≒ 2*tan(垂直FOV/2)）。
    static func metersDown(normalizedDeltaY: CGFloat, depth: Float, depthToMetersFactor: Float) -> CGFloat {
        normalizedDeltaY * CGFloat(depth * depthToMetersFactor)
    }

    /// 実寸下方向速度 (m/s)。
    static func metricVerticalSpeed(
        normalizedDeltaY: CGFloat,
        dt: TimeInterval,
        depth: Float,
        depthToMetersFactor: Float
    ) -> CGFloat {
        guard dt > 0 else { return 0 }
        return metersDown(normalizedDeltaY: normalizedDeltaY, depth: depth, depthToMetersFactor: depthToMetersFactor) / CGFloat(dt)
    }
}
