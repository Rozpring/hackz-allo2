import Combine
import CoreGraphics
import Foundation
import GameCore

// issue #34 (tasks 9.2): モジュール間の連鎖を検証する統合チェック。
// 対象は「自分の担当モジュール間の結線」:
//   A) MockHandLandmarkProvider → HandSwingDetector → PowerCalculator（手検出→速度→威力）
//   B) faceUpCards → GameStateManager.onBoardSettled（静止→ペア検出→スコア更新）
// アプリ全体のフレーム分配/E2E結線（#30/#31, kyiku）は #35 実機E2Eで確認する。

private struct IntegConfig: SwingConfig, PowerConfig, ScoringConfig {
    // SwingConfig
    var swingVelocityThreshold: CGFloat = 1.5
    var punchCooldown: TimeInterval = 0.3
    var velocityEMAAlpha: CGFloat = 0.7
    var landingDecelerationFraction: CGFloat = 0.5
    var maxSampleGap: TimeInterval = 0.1
    // PowerConfig
    var minPower: Float = 0.2
    var maxPower: Float = 1.0
    var velocityForMinPower: CGFloat = 1.0
    var velocityForMaxPower: CGFloat = 5.0
    // ScoringConfig
    var pairCount: Int = 4
    var timeLimitSeconds: Int = 30
    var basePairScore: Int = 100
    var comboMultiplierStep: Float = 0.5
}

private struct TestCard: MatchableCard {
    let id: Int; let rank: Int; var isFaceUp: Bool
}

private func swingY(descentFrames: Int, step: CGFloat, startY: CGFloat, stopFrames: Int) -> [CGFloat] {
    var ys: [CGFloat] = [startY]; var y = startY
    for _ in 0..<descentFrames { y += step; ys.append(y) }
    for _ in 0..<stopFrames { ys.append(y) }
    return ys
}

/// 手検出→速度→威力の連鎖で、台パン1回から威力を1つ得る。
private func powerFromSwing(_ ys: [CGFloat], config: IntegConfig) -> Float? {
    let provider = MockHandLandmarkProvider()
    let detector = HandSwingDetector(provider: provider, config: config)
    let calc = PowerCalculator(config: config)
    var power: Float?
    let c = detector.punches.sink { event in
        power = calc.power(from: event.peakVelocity)
    }
    provider.emitSeries(yPositions: ys, startTime: 0, interval: 1.0 / 60.0)
    c.cancel()
    return power
}

func runChecks_9_2() {
    section("#34 (9.2) 統合: 手検出→速度→威力／静止→ペア→スコア")
    let config = IntegConfig()

    // A) 連鎖が1本通り、威力が範囲内に出る
    do {
        let strong = swingY(descentFrames: 10, step: 0.06, startY: 0.1, stopFrames: 5)
        let p = powerFromSwing(strong, config: config)
        check(p != nil, "MockProvider→SwingDetector→PowerCalculator が1本通り威力が得られる")
        if let p {
            check(p >= config.minPower && p <= config.maxPower, "威力が [minPower,maxPower] に収まる (\(p))")
        }
    }

    // A') 強い台パンほど威力が大きい（単調性が連鎖を貫通する）
    do {
        let weak = swingY(descentFrames: 10, step: 0.035, startY: 0.1, stopFrames: 5)   // ~2.1/s
        let strong = swingY(descentFrames: 10, step: 0.08, startY: 0.05, stopFrames: 5) // ~4.8/s
        if let pw = powerFromSwing(weak, config: config), let ps = powerFromSwing(strong, config: config) {
            check(ps > pw, "強い振り下ろしの方が威力が大きい (weak=\(pw), strong=\(ps))")
        } else {
            check(false, "（前提）弱・強どちらの台パンも成立する")
        }
    }

    // B) 静止→ペア検出→スコア更新の連鎖
    do {
        let gm = GameStateManager(config: config)
        gm.startGame()
        let faceUp = [
            TestCard(id: 1, rank: 3, isFaceUp: true), TestCard(id: 2, rank: 3, isFaceUp: true),
            TestCard(id: 3, rank: 7, isFaceUp: true), TestCard(id: 4, rank: 7, isFaceUp: true),
        ]
        let collected = gm.onBoardSettled(faceUpCards: faceUp)
        check(collected.count == 2, "静止確定で2ペアが回収対象として返る")
        check(gm.score == 200, "スコアが 100×2 = 200 に更新 (got \(gm.score))")
        check(gm.remainingPairs == 2, "残ペアが 4→2 に更新")
    }

    // B') 威力記録 → HUD 用 lastPower が連動
    do {
        let gm = GameStateManager(config: config)
        gm.startGame()
        let strong = swingY(descentFrames: 10, step: 0.06, startY: 0.1, stopFrames: 5)
        if let p = powerFromSwing(strong, config: config) {
            gm.recordPunch(power: p)
            check(gm.lastPower == p, "台パン威力が GameStateManager.lastPower に反映（HUD連動）")
        } else {
            check(false, "（前提）台パンが成立する")
        }
    }
}
