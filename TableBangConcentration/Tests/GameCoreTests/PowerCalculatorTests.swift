import CoreGraphics
import XCTest
import GameCore

// issue #33 (tasks 9.1) の一部。Xcode のアプリ用テストターゲットで実行する想定。
// 実行可能版は SPM の `GameCoreChecks`（swift run GameCoreChecks）にも同等シナリオがある。

private struct TestPowerConfig: PowerConfig {
    var minPower: Float = 0.2
    var maxPower: Float = 1.0
    var velocityForMinPower: CGFloat = 1.0
    var velocityForMaxPower: CGFloat = 5.0
}

final class PowerCalculatorTests: XCTestCase {
    private let config = TestPowerConfig()
    private lazy var calc = PowerCalculator(config: config)

    func testClampBelowAndAbove() {
        XCTAssertEqual(calc.power(from: 0.0), config.minPower)
        XCTAssertEqual(calc.power(from: 10.0), config.maxPower)
    }

    func testEndpoints() {
        XCTAssertEqual(calc.power(from: config.velocityForMinPower), config.minPower)
        XCTAssertEqual(calc.power(from: config.velocityForMaxPower), config.maxPower)
    }

    func testMidpointLinear() {
        XCTAssertEqual(calc.power(from: 3.0), 0.6, accuracy: 1e-6)
    }

    func testMonotonicIncreasing() {
        var previous = calc.power(from: 0.0)
        var v: CGFloat = 0.0
        while v <= 6.0 {
            let p = calc.power(from: v)
            XCTAssertGreaterThanOrEqual(p, previous - 1e-6)
            previous = p
            v += 0.25
        }
    }

    func testAlwaysInRange() {
        var v: CGFloat = -2.0
        while v <= 8.0 {
            let p = calc.power(from: v)
            XCTAssertGreaterThanOrEqual(p, config.minPower - 1e-6)
            XCTAssertLessThanOrEqual(p, config.maxPower + 1e-6)
            v += 0.3
        }
    }

    func testDegenerateConfigDoesNotCrash() {
        struct BadConfig: PowerConfig {
            var minPower: Float = 0.1; var maxPower: Float = 0.9
            var velocityForMinPower: CGFloat = 5.0; var velocityForMaxPower: CGFloat = 5.0
        }
        XCTAssertEqual(PowerCalculator(config: BadConfig()).power(from: 3.0), 0.1)
    }
}
