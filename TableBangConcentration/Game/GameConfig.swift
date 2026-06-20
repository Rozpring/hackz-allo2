import Foundation
import CoreGraphics
import simd

/// 調整パラメータの集約（R10-5）。実機チューニング前提のたたき台値を `default` に持つ。
struct GameConfig {
    // MARK: 入力 / 威力
    /// 台パンとみなす画面座標系の下方向速度しきい値（/s, 正規化座標基準）
    var swingVelocityThreshold: CGFloat
    /// 最大威力に達する速度（正規化/s）。正規化の上端。
    var velocityForMaxPower: CGFloat
    /// 連打抑制のクールダウン
    var punchCooldown: TimeInterval
    var minPower: Float
    var maxPower: Float

    // MARK: 衝撃波 / 物理
    var radiusForMinPower: Float
    var radiusForMaxPower: Float
    var upwardBias: Float
    var impulseJitter: ClosedRange<Float>
    var torqueRange: ClosedRange<Float>
    var cardMass: Float
    var friction: Float
    var restitution: Float
    var settleLinearThreshold: Float
    var settleAngularThreshold: Float
    var settleFrameCount: Int

    // MARK: 盤面 / 進行
    var pairCount: Int
    var gridColumns: Int
    /// カードの物理寸法 [幅, 厚み, 奥行] (m)。薄い箱。
    var cardSize: SIMD3<Float>
    /// 格子セル間隔 (m)
    var cardSpacing: Float
    /// 盤面外周〜不可視壁までの余白 (m)
    var boardInset: Float
    /// 外周不可視壁の高さ (m)。カードが盤外へ飛び出すのを防ぐ。
    var boardWallHeight: Float
    /// 盤面配置に必要な検出平面の最小辺長 (m)（R1-5）。
    var minPlaneSide: Float
    var timeLimitSeconds: Int
    var comboMultiplierStep: Float
    /// 1ペア成立あたりの基礎得点。
    var scorePerPair: Int
}

extension GameConfig {
    /// 実機チューニング前のたたき台。
    static let `default` = GameConfig(
        swingVelocityThreshold: 1.5,
        velocityForMaxPower: 6.0,
        punchCooldown: 0.4,
        minPower: 0.0,
        maxPower: 1.0,
        radiusForMinPower: 0.05,
        radiusForMaxPower: 0.25,
        upwardBias: 0.4,
        impulseJitter: (-0.05)...(0.05),
        torqueRange: (-0.02)...(0.02),
        cardMass: 0.02,
        friction: 0.5,
        restitution: 0.2,
        settleLinearThreshold: 0.02,
        settleAngularThreshold: 0.05,
        settleFrameCount: 8,
        pairCount: 8,
        gridColumns: 4,
        cardSize: SIMD3<Float>(0.06, 0.002, 0.09),
        cardSpacing: 0.08,
        boardInset: 0.05,
        boardWallHeight: 0.1,
        minPlaneSide: 0.3,
        timeLimitSeconds: 90,
        comboMultiplierStep: 0.5,
        scorePerPair: 100
    )
}
