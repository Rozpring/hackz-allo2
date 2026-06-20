import CoreGraphics
import Foundation

/// 台パンのピーク速度を威力値 `[minPower, maxPower]` へ線形正規化（クランプ）する。
///
/// - `velocityForMinPower` 以下 → `minPower`
/// - `velocityForMaxPower` 以上 → `maxPower`
/// - その間は線形補間（速度に対し**単調増加**）
///
/// 速度は px/s（正規化/s）の相対量で、カメラと手の距離・画角に依存する（research.md §2）。
/// そのため速度→威力の対応点（`velocityForMin/MaxPower`）は調整パラメータとして外出しする。
///
/// 設計対応: design.md `PowerCalculator`。要件 4.2, 4.3。
public struct PowerCalculator {
    private let config: PowerConfig

    public init(config: PowerConfig) {
        self.config = config
    }

    /// ピーク速度から威力を求める。戻り値は必ず `config.minPower...config.maxPower` に収まる。
    public func power(from peakVelocity: CGFloat) -> Float {
        let vMin = config.velocityForMinPower
        let vMax = config.velocityForMaxPower

        // 不正な設定（vMax <= vMin）でも破綻せず minPower を返す。
        guard vMax > vMin else { return config.minPower }

        let clampedVelocity = min(max(peakVelocity, vMin), vMax)
        let t = Float((clampedVelocity - vMin) / (vMax - vMin))  // [0,1]
        return config.minPower + t * (config.maxPower - config.minPower)
    }
}
