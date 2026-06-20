import XCTest
@testable import TableBangConcentration

final class PowerCalculatorTests: XCTestCase {
    private let calc = PowerCalculator(config: .default)
    private let c = GameConfig.default

    func testClampsBelowThreshold() {
        XCTAssertEqual(calc.power(from: 0), c.minPower, accuracy: 1e-6)
        XCTAssertEqual(calc.power(from: c.swingVelocityThreshold), c.minPower, accuracy: 1e-6)
    }

    func testClampsAboveMax() {
        XCTAssertEqual(calc.power(from: c.velocityForMaxPower), c.maxPower, accuracy: 1e-6)
        XCTAssertEqual(calc.power(from: c.velocityForMaxPower * 2), c.maxPower, accuracy: 1e-6)
    }

    func testMonotonicIncreasing() {
        let p1 = calc.power(from: c.swingVelocityThreshold + 0.5)
        let p2 = calc.power(from: c.swingVelocityThreshold + 1.5)
        let p3 = calc.power(from: c.swingVelocityThreshold + 2.5)
        XCTAssertLessThan(p1, p2)
        XCTAssertLessThan(p2, p3)
    }
}
