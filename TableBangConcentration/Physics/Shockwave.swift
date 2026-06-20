import Foundation
import simd

/// 衝撃波の純関数群（半径・距離減衰・インパルス方向）。テスト容易性のため副作用と分離（R5-2, R5-3）。
enum Shockwave {
    /// 威力 [minPower, maxPower] を影響半径 [radiusForMinPower, radiusForMaxPower] へ線形写像（範囲外はクランプ）。
    static func radius(forPower power: Float, config: GameConfig) -> Float {
        let lo = config.minPower
        let hi = config.maxPower
        guard hi > lo else { return config.radiusForMinPower }
        let t = min(max((power - lo) / (hi - lo), 0), 1)
        return config.radiusForMinPower + t * (config.radiusForMaxPower - config.radiusForMinPower)
    }

    /// 距離減衰係数 `max(0, 1 - dist/radius)`。中心で1、半径以遠で0。
    static func falloff(distance: Float, radius: Float) -> Float {
        guard radius > 0 else { return 0 }
        return max(0, 1 - distance / radius)
    }

    /// インパルス方向 = 水平成分を正規化したベクトルに上方バイアスを加算した合成ベクトル。
    /// カードは平面上にあるため delta の垂直成分は無視し、水平成分のみ正規化する。
    /// 大きさは sqrt(1 + upwardBias²) となる（意図的に正規化しない）。
    static func direction(delta: SIMD3<Float>, upwardBias: Float) -> SIMD3<Float> {
        let horizontal = SIMD3<Float>(delta.x, 0, delta.z)
        let length = simd.length(horizontal)
        let unit = length > 1e-5 ? horizontal / length : SIMD3<Float>(0, 0, 0)
        return unit + SIMD3<Float>(0, upwardBias, 0)
    }
}
