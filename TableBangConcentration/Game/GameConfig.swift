import Foundation
import CoreGraphics
import simd

/// 調整パラメータの集約（R10-5）。実機チューニング前提のたたき台値を `default` に持つ。
struct GameConfig {
    // MARK: 入力 / 威力
    /// 台パンとみなす下方向速度しきい値（m/s, 実寸）。LiDAR深度で実速度に換算して比較する。
    var swingVelocityThreshold: CGFloat
    /// 最大威力に達する速度（m/s, 実寸）。これ以上は威力上限。
    var velocityForMaxPower: CGFloat
    /// 連打抑制のクールダウン
    var punchCooldown: TimeInterval
    /// この間隔を超えてサンプルが途切れたら検出の不連続とみなす（着地確定/状態リセットの境界）。
    var maxSampleGap: TimeInterval
    /// 深度が取得できない時に使う手の想定距離 (m)。LiDARフォールバック。
    var nominalHandDepth: Float
    /// 正規化画面移動量×深度 を実寸メートルへ変換する係数（≒ 2*tan(垂直FOV/2)。実機チューニング対象）。
    var depthToMetersFactor: Float
    var minPower: Float
    var maxPower: Float

    // MARK: 衝撃波 / 物理
    var radiusForMinPower: Float
    var radiusForMaxPower: Float
    var upwardBias: Float
    /// 威力(0..1)×距離減衰 をニュートン秒インパルスへ変換する係数（実機チューニング対象）。
    var impulseScale: Float
    var impulseJitter: ClosedRange<Float>
    var torqueRange: ClosedRange<Float>
    var cardMass: Float
    var friction: Float
    var restitution: Float
    var settleLinearThreshold: Float
    var settleAngularThreshold: Float
    var settleFrameCount: Int

    // MARK: 盤面 / 進行
    /// 盤面の格子列数（標準52枚デッキを並べる）。
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
    var comboMultiplierStep: Float
    /// 1ペア成立あたりの基礎得点。
    var scorePerPair: Int
}

extension GameConfig {
    /// 実機チューニング前のたたき台。
    static let `default` = GameConfig(
        swingVelocityThreshold: 0.8,
        velocityForMaxPower: 3.0,
        punchCooldown: 0.4,
        maxSampleGap: 0.2,
        nominalHandDepth: 0.5,
        depthToMetersFactor: 1.2,
        minPower: 0.0,
        maxPower: 1.0,
        radiusForMinPower: 0.12,
        radiusForMaxPower: 0.55,
        upwardBias: 0.4,
        impulseScale: 0.05,
        impulseJitter: (-0.005)...(0.005),
        torqueRange: (-0.0006)...(0.0006),
        cardMass: 0.02,
        friction: 0.5,
        restitution: 0.2,
        settleLinearThreshold: 0.02,
        settleAngularThreshold: 0.05,
        settleFrameCount: 8,
        gridColumns: 8, // 52枚 → 8列×7行
        cardSize: SIMD3<Float>(0.05, 0.002, 0.07),
        cardSpacing: 0.075,
        boardInset: 0.05,
        boardWallHeight: 0.3,
        minPlaneSide: 0.3,
        comboMultiplierStep: 0.5,
        scorePerPair: 100
    )
}
