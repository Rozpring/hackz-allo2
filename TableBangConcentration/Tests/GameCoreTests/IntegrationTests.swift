import Combine
import CoreGraphics
import XCTest
import GameCore

// issue #34 (tasks 9.2) の XCTest 版。実行可能版は GameCoreChecks の runChecks_9_2 にある。
// 対象は自分担当モジュール間の結線。アプリ全体のフレーム分配/E2E(#30/#31, kyiku)は #35 実機E2Eで確認。

private struct IntegConfig: SwingConfig, PowerConfig, ScoringConfig {
    var swingVelocityThreshold: CGFloat = 1.5
    var punchCooldown: TimeInterval = 0.3
    var velocityEMAAlpha: CGFloat = 0.7
    var landingDecelerationFraction: CGFloat = 0.5
    var maxSampleGap: TimeInterval = 0.1
    var minPower: Float = 0.2
    var maxPower: Float = 1.0
    var velocityForMinPower: CGFloat = 1.0
    var velocityForMaxPower: CGFloat = 5.0
    var pairCount: Int = 4
    var timeLimitSeconds: Int = 30
    var basePairScore: Int = 100
    var comboMultiplierStep: Float = 0.5
}

private struct TestCard: MatchableCard {
    let id: Int; let rank: Int; var isFaceUp: Bool
}

final class IntegrationTests: XCTestCase {
    private let config = IntegConfig()

    private func swingY(descentFrames: Int, step: CGFloat, startY: CGFloat, stopFrames: Int) -> [CGFloat] {
        var ys: [CGFloat] = [startY]; var y = startY
        for _ in 0..<descentFrames { y += step; ys.append(y) }
        for _ in 0..<stopFrames { ys.append(y) }
        return ys
    }

    private func powerFromSwing(_ ys: [CGFloat]) -> Float? {
        let provider = MockHandLandmarkProvider()
        let detector = HandSwingDetector(provider: provider, config: config)
        let calc = PowerCalculator(config: config)
        var power: Float?
        let c = detector.punches.sink { power = calc.power(from: $0.peakVelocity) }
        provider.emitSeries(yPositions: ys, startTime: 0, interval: 1.0 / 60.0)
        c.cancel()
        return power
    }

    func testHandToPowerChain() {
        let p = powerFromSwing(swingY(descentFrames: 10, step: 0.06, startY: 0.1, stopFrames: 5))
        XCTAssertNotNil(p)
        XCTAssertGreaterThanOrEqual(p ?? 0, config.minPower)
        XCTAssertLessThanOrEqual(p ?? 1, config.maxPower)
    }

    func testStrongerSwingYieldsMorePower() {
        let weak = powerFromSwing(swingY(descentFrames: 10, step: 0.035, startY: 0.1, stopFrames: 5))
        let strong = powerFromSwing(swingY(descentFrames: 10, step: 0.08, startY: 0.05, stopFrames: 5))
        XCTAssertNotNil(weak); XCTAssertNotNil(strong)
        XCTAssertGreaterThan(strong ?? 0, weak ?? 0)
    }

    func testSettleToScoreChain() {
        let gm = GameStateManager(config: config)
        gm.startGame()
        let faceUp = [
            TestCard(id: 1, rank: 3, isFaceUp: true), TestCard(id: 2, rank: 3, isFaceUp: true),
            TestCard(id: 3, rank: 7, isFaceUp: true), TestCard(id: 4, rank: 7, isFaceUp: true),
        ]
        let collected = gm.onBoardSettled(faceUpCards: faceUp)
        XCTAssertEqual(collected.count, 2)
        XCTAssertEqual(gm.score, 200)
        XCTAssertEqual(gm.remainingPairs, 2)
    }
}
