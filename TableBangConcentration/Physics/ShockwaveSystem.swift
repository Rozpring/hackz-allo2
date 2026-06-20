import Foundation
import simd

/// 1枚のカードへ与えるインパルス計画（純データ）。`emit` 時に物理へ適用する。
struct CardImpulse {
    let card: CardEntity
    let impulse: SIMD3<Float>
    /// 重心からずらした打点（非決定論的な回転を生む）。
    let offset: SIMD3<Float>
    let torque: SIMD3<Float>
}

/// 威力から影響半径を決め、半径内の各カードへ距離減衰インパルス＋ランダムトルクを与える（R5-1〜R5-5, R5-8）。
/// 重心オフセット打点・軸ランダムトルク・微小ランダム並進で非決定論的な跳ね・回転を生む。
struct ShockwaveSystem {
    let cardManager: CardManaging
    let config: GameConfig

    /// 半径内カードへインパルスを適用する。
    func emit(at center: SIMD3<Float>, power: Float) {
        var rng = SystemRandomNumberGenerator()
        let impulses = plan(at: center, power: power, using: &rng)
        impulses.forEach { $0.card.applyShock(impulse: $0.impulse, at: $0.offset, torque: $0.torque) }
    }

    /// 適用するインパルス計画を生成する（純粋。乱数源を注入してテスト可能）。
    func plan<G: RandomNumberGenerator>(
        at center: SIMD3<Float>,
        power: Float,
        using rng: inout G
    ) -> [CardImpulse] {
        let radius = Shockwave.radius(forPower: power, config: config)
        let targets = cardManager.cards(within: radius, of: center)

        return targets.map { card in
            let delta = card.position - center
            let distance = simd.length(delta)
            let falloff = Shockwave.falloff(distance: distance, radius: radius)
            let direction = Shockwave.direction(delta: delta, upwardBias: config.upwardBias)

            let jitter = SIMD3<Float>(
                Float.random(in: config.impulseJitter, using: &rng),
                Float.random(in: config.impulseJitter, using: &rng),
                Float.random(in: config.impulseJitter, using: &rng)
            )
            // falloff=0（半径境界上）のカードは不変に保つ。半径内のみ微小 jitter を加える。
            let scaled = direction * power * falloff
            let impulse = falloff > 0 ? scaled + jitter : scaled

            let torque = SIMD3<Float>(
                Float.random(in: config.torqueRange, using: &rng),
                Float.random(in: config.torqueRange, using: &rng),
                Float.random(in: config.torqueRange, using: &rng)
            )
            // 重心から水平にわずかにずらした打点。
            let offset = SIMD3<Float>(
                Float.random(in: config.impulseJitter, using: &rng),
                0,
                Float.random(in: config.impulseJitter, using: &rng)
            )
            return CardImpulse(card: card, impulse: impulse, offset: offset, torque: torque)
        }
    }
}
