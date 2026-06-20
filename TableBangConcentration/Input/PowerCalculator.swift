import Foundation
import CoreGraphics

/// ピーク速度を威力値 [minPower, maxPower] へクランプ正規化する（R4-2, R4-3）。
struct PowerCalculator {
    let config: GameConfig

    /// `peakVelocity` を `swingVelocityThreshold`..`velocityForMaxPower` で正規化し、
    /// `minPower`..`maxPower` にクランプして返す。単調増加。
    func power(from peakVelocity: CGFloat) -> Float {
        let v = Float(peakVelocity)
        let lo = Float(config.swingVelocityThreshold)
        let hi = Float(config.velocityForMaxPower)
        guard hi > lo else { return config.minPower }
        let t = (v - lo) / (hi - lo)
        let clamped = min(max(t, 0), 1)
        return config.minPower + clamped * (config.maxPower - config.minPower)
    }
}
