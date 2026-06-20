import Combine
import CoreGraphics
import XCTest
import GameCore

private struct TestSwingConfig: SwingConfig {
    var swingVelocityThreshold: CGFloat = 1.5
    var punchCooldown: TimeInterval = 0.3
    var velocityEMAAlpha: CGFloat = 0.7
    var landingDecelerationFraction: CGFloat = 0.5
    var maxSampleGap: TimeInterval = 0.1
}

final class HandSwingDetectorTests: XCTestCase {
    private let config = TestSwingConfig()

    private func feed(_ yPositions: [CGFloat], x: CGFloat = 0.5) -> [TablePunchEvent] {
        let provider = MockHandLandmarkProvider()
        let detector = HandSwingDetector(provider: provider, config: config)
        var punches: [TablePunchEvent] = []
        let c = detector.punches.sink { punches.append($0) }
        provider.emitSeries(yPositions: yPositions, x: x, startTime: 0, interval: 1.0 / 60.0)
        c.cancel()
        return punches
    }

    private func swing(descentFrames: Int, step: CGFloat, startY: CGFloat, stopFrames: Int) -> [CGFloat] {
        var ys: [CGFloat] = [startY]
        var y = startY
        for _ in 0..<descentFrames { y += step; ys.append(y) }
        for _ in 0..<stopFrames { ys.append(y) }
        return ys
    }

    func testStrongSwingFiresOnce() {
        let punches = feed(swing(descentFrames: 10, step: 0.05, startY: 0.2, stopFrames: 5))
        XCTAssertEqual(punches.count, 1)
        XCTAssertGreaterThan(punches.first?.peakVelocity ?? 0, config.swingVelocityThreshold)
    }

    func testWeakSwingDoesNotFire() {
        let punches = feed(swing(descentFrames: 12, step: 0.02, startY: 0.2, stopFrames: 5))
        XCTAssertTrue(punches.isEmpty)
    }

    func testCooldownSuppressesSecond() {
        let s1 = swing(descentFrames: 10, step: 0.05, startY: 0.05, stopFrames: 2)
        let s2 = swing(descentFrames: 10, step: 0.05, startY: 0.05, stopFrames: 5)
        XCTAssertEqual(feed(s1 + s2).count, 1)
    }

    func testTwoSwingsBeyondCooldownFireTwice() {
        let s1 = swing(descentFrames: 10, step: 0.05, startY: 0.05, stopFrames: 2)
        let gapStill = Array(repeating: CGFloat(0.55), count: 30)
        let s2 = swing(descentFrames: 10, step: 0.05, startY: 0.05, stopFrames: 5)
        XCTAssertEqual(feed(s1 + gapStill + s2).count, 2)
    }

    func testLandingPointInEvent() {
        let punches = feed(swing(descentFrames: 10, step: 0.05, startY: 0.2, stopFrames: 5), x: 0.73)
        XCTAssertEqual(Double(punches.first?.screenPoint.x ?? -1), 0.73, accuracy: 1e-9)
    }
}
