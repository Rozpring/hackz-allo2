import CoreGraphics
import Foundation

// MARK: - 調整パラメータの契約（protocol）
//
// design.md の `GameConfig`（issue #11, kyiku 担当）に集約される調整値のうち、
// GameCore の各ロジックが「消費する」分だけを protocol として切り出す。
// 本番では kyiku の `GameConfig` がこれらに適合する。テストでは軽量な構造体を適合させる。
// こうすることで GameCore は具体的な `GameConfig` 型に依存せず、差し替え可能・単体テスト可能になる。

/// `HandSwingDetector` が参照する速度/台パン判定パラメータ。要件 4.1, 4.5。
public protocol SwingConfig {
    /// 下方向ピーク速度がこの値を超えていなければ台パンとみなさない（画面正規化座標/秒）。
    var swingVelocityThreshold: CGFloat { get }
    /// 台パン成立後、この秒数が経過するまで次の成立を抑制する（過剰連打防止）。
    var punchCooldown: TimeInterval { get }
    /// 速度平滑化（EMA）の係数 [0,1]。大きいほど最新値を重視する。
    var velocityEMAAlpha: CGFloat { get }
    /// 着地判定。下降中ピークに対し、現在の下方向速度がこの割合以下へ急減速したら「着地」とみなす [0,1]。
    var landingDecelerationFraction: CGFloat { get }
    /// サンプル間隔がこの秒数を超えたら手検出が途切れたとみなし、進行中の下降状態をリセットする。
    var maxSampleGap: TimeInterval { get }
}

/// `PowerCalculator` が参照する威力正規化パラメータ。要件 4.2, 4.3。
public protocol PowerConfig {
    /// 威力の下限（クランプ後の最小値）。
    var minPower: Float { get }
    /// 威力の上限（クランプ後の最大値）。
    var maxPower: Float { get }
    /// この速度以下では威力を `minPower` にする（画面正規化座標/秒）。
    var velocityForMinPower: CGFloat { get }
    /// この速度以上では威力を `maxPower` にする（画面正規化座標/秒）。
    var velocityForMaxPower: CGFloat { get }
}

/// `GameStateManager` が参照するスコア/進行パラメータ。要件 6.3, 6.4, 8.1, 8.5。
public protocol ScoringConfig {
    /// 盤面のペア総数（=初期残ペア）。例: 8。
    var pairCount: Int { get }
    /// 制限時間（秒）。
    var timeLimitSeconds: Int { get }
    /// 1ペア回収あたりの基礎点。
    var basePairScore: Int { get }
    /// コンボ1段あたりの倍率増分。multiplier = 1 + comboMultiplierStep * (連続得点回数 - 1)。
    var comboMultiplierStep: Float { get }
}
