import XCTest
import simd
@testable import TableBangConcentration

final class ShockwaveTests: XCTestCase {
    private let config = GameConfig.default

    // MARK: 影響半径（威力 → 半径）

    func testRadiusIsMonotonicIncreasingInPower() {
        let r0 = Shockwave.radius(forPower: 0.0, config: config)
        let rMid = Shockwave.radius(forPower: 0.5, config: config)
        let r1 = Shockwave.radius(forPower: 1.0, config: config)
        XCTAssertLessThan(r0, rMid)
        XCTAssertLessThan(rMid, r1)
    }

    func testRadiusClampsToConfiguredRange() {
        XCTAssertEqual(Shockwave.radius(forPower: -5, config: config), config.radiusForMinPower, accuracy: 1e-6)
        XCTAssertEqual(Shockwave.radius(forPower: 99, config: config), config.radiusForMaxPower, accuracy: 1e-6)
    }

    // MARK: 距離減衰

    func testFalloffIsOneAtCenter() {
        XCTAssertEqual(Shockwave.falloff(distance: 0, radius: 0.2), 1.0, accuracy: 1e-6)
    }

    func testFalloffIsZeroAtAndBeyondRadius() {
        XCTAssertEqual(Shockwave.falloff(distance: 0.2, radius: 0.2), 0.0, accuracy: 1e-6)
        XCTAssertEqual(Shockwave.falloff(distance: 0.5, radius: 0.2), 0.0, accuracy: 1e-6)
    }

    func testFalloffIsLinearAndDecreasing() {
        let near = Shockwave.falloff(distance: 0.05, radius: 0.2)
        let far = Shockwave.falloff(distance: 0.15, radius: 0.2)
        XCTAssertEqual(Shockwave.falloff(distance: 0.1, radius: 0.2), 0.5, accuracy: 1e-6)
        XCTAssertGreaterThan(near, far)
    }

    // MARK: インパルス方向（水平外向き + 上方バイアス）

    func testDirectionHasHorizontalUnitPlusUpwardBias() {
        let dir = Shockwave.direction(delta: SIMD3<Float>(2, 0, 0), upwardBias: 0.4)
        XCTAssertEqual(dir.x, 1.0, accuracy: 1e-6)
        XCTAssertEqual(dir.z, 0.0, accuracy: 1e-6)
        XCTAssertEqual(dir.y, 0.4, accuracy: 1e-6, "上方バイアスは常に y へ加算")
    }

    func testDirectionAtCenterIsPurelyUpward() {
        let dir = Shockwave.direction(delta: SIMD3<Float>(0, 0, 0), upwardBias: 0.4)
        XCTAssertEqual(dir.x, 0.0, accuracy: 1e-6)
        XCTAssertEqual(dir.z, 0.0, accuracy: 1e-6)
        XCTAssertEqual(dir.y, 0.4, accuracy: 1e-6)
    }

    func testDirectionIgnoresVerticalComponentOfDelta() {
        // 水平成分のみを正規化に使う（カードは平面上なので上下の delta は無視）
        let dir = Shockwave.direction(delta: SIMD3<Float>(0, 5, 3), upwardBias: 0.2)
        XCTAssertEqual(dir.x, 0.0, accuracy: 1e-6)
        XCTAssertEqual(dir.z, 1.0, accuracy: 1e-6)
        XCTAssertEqual(dir.y, 0.2, accuracy: 1e-6)
    }
}

final class ShockwaveSystemPlanTests: XCTestCase {
    func testStrongerPunchAffectsMoreCards() {
        // 格子間隔(0.08)に対し、最小半径は1枚程度・最大半径は複数枚をカバーする値に固定
        var config = GameConfig.default
        config.radiusForMinPower = 0.05
        config.radiusForMaxPower = 0.30
        let manager = CardManager()
        manager.buildBoard(config: config)
        let system = ShockwaveSystem(cardManager: manager, config: config)
        let center = manager.cards[0].position

        var rng1 = SystemRandomNumberGenerator()
        let weak = system.plan(at: center, power: 0.0, using: &rng1)
        var rng2 = SystemRandomNumberGenerator()
        let strong = system.plan(at: center, power: 1.0, using: &rng2)

        XCTAssertGreaterThanOrEqual(weak.count, 1, "打点直上のカードは弱くても対象")
        XCTAssertGreaterThan(strong.count, weak.count, "強い台パンほど影響半径が広く対象が増える")
    }

    func testPlanOnlyTargetsCardsWithinRadius() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        let system = ShockwaveSystem(cardManager: manager, config: .default)
        let center = SIMD3<Float>(0, 0, 0)

        var rng = SystemRandomNumberGenerator()
        let plan = system.plan(at: center, power: 1.0, using: &rng)
        let radius = Shockwave.radius(forPower: 1.0, config: .default)
        XCTAssertTrue(plan.allSatisfy { simd.distance($0.card.position, center) <= radius })
    }
}
