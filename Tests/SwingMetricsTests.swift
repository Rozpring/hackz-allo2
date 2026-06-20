import XCTest
import CoreGraphics
@testable import TableBangConcentration

final class SwingMetricsTests: XCTestCase {
    func testMetricSpeedScalesWithDepth() {
        // 同じ画面移動量・同じΔtでも、手が遠い（depth大）ほど実寸の移動は大きい＝実速度も大きい
        let near = SwingMetrics.metricVerticalSpeed(normalizedDeltaY: 0.2, dt: 0.1, depth: 0.3, depthToMetersFactor: 1.2)
        let far = SwingMetrics.metricVerticalSpeed(normalizedDeltaY: 0.2, dt: 0.1, depth: 0.6, depthToMetersFactor: 1.2)
        XCTAssertGreaterThan(far, near)
        // far は near のちょうど2倍（depthが2倍）
        XCTAssertEqual(far, near * 2, accuracy: 1e-5)
    }

    func testMetricSpeedFormula() {
        // metersDown = 0.5 * 0.5 * 1.2 = 0.3 m, /dt(0.5) = 0.6 m/s
        let v = SwingMetrics.metricVerticalSpeed(normalizedDeltaY: 0.5, dt: 0.5, depth: 0.5, depthToMetersFactor: 1.2)
        XCTAssertEqual(v, 0.6, accuracy: 1e-5)
    }

    func testZeroDtIsSafe() {
        XCTAssertEqual(SwingMetrics.metricVerticalSpeed(normalizedDeltaY: 0.2, dt: 0, depth: 0.5, depthToMetersFactor: 1.2), 0)
    }
}
