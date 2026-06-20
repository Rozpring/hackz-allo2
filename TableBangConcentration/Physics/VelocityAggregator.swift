import Foundation
import simd
import RealityKit

/// 可動カード群の最大速度を集約する純関数（`PhysicsSettleObserver` の静止判定入力, R10-4）。
enum VelocityAggregator {
    /// 全カードの線形/角速度の大きさの最大値を返す。回収済み・物理情報なしは0扱い。
    static func maxSpeeds(cards: [CardEntity]) -> (linear: Float, angular: Float) {
        var maxLinear: Float = 0
        var maxAngular: Float = 0
        for card in cards where card.state != .collected {
            let motion = card.physicsMotion
            let linear = simd.length(motion?.linearVelocity ?? .zero)
            let angular = simd.length(motion?.angularVelocity ?? .zero)
            maxLinear = max(maxLinear, linear)
            maxAngular = max(maxAngular, angular)
        }
        return (maxLinear, maxAngular)
    }
}
