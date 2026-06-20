import Foundation
import CoreGraphics

/// 台パン成立イベント。手検出から物理・ゲームロジックへの起点。
struct TablePunchEvent: Equatable {
    /// 画面座標系の相対ピーク速度（/s）
    let peakVelocity: CGFloat
    /// 着地時の代表点（AR平面への投影元）
    let screenPoint: CGPoint
}
