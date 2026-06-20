import XCTest
import CoreGraphics
@testable import TableBangConcentration

final class HandSwingDetectorTests: XCTestCase {
    private let dt = 0.05

    /// 下降サンプル列（y増加）を流し、続けて停止サンプル列を流す。
    /// 成立した最初の `TablePunchEvent` を返す。
    @discardableResult
    private func feedSwingThenStop(
        _ detector: HandSwingDetector,
        startTime: TimeInterval,
        startY: CGFloat,
        descendSteps: Int = 6,
        descendDelta: CGFloat = 0.5,
        stopSteps: Int = 8
    ) -> (event: TablePunchEvent?, endTime: TimeInterval, endY: CGFloat) {
        var t = startTime
        var y = startY
        var captured: TablePunchEvent?
        for _ in 0..<descendSteps {
            if let e = detector.process(.init(screenPoint: CGPoint(x: 0.5, y: y), timestamp: t, confidence: 0.9)) {
                captured = captured ?? e
            }
            t += dt
            y += descendDelta
        }
        for _ in 0..<stopSteps {
            if let e = detector.process(.init(screenPoint: CGPoint(x: 0.5, y: y), timestamp: t, confidence: 0.9)) {
                captured = captured ?? e
            }
            t += dt
        }
        return (captured, t, y)
    }

    func testDetectsPunchOnDescendThenStop() {
        let detector = HandSwingDetector(config: .default)
        let result = feedSwingThenStop(detector, startTime: 0, startY: 0.1)
        XCTAssertNotNil(result.event)
        XCTAssertGreaterThanOrEqual(result.event!.peakVelocity, GameConfig.default.swingVelocityThreshold)
    }

    func testSlowMovementDoesNotTrigger() {
        let detector = HandSwingDetector(config: .default)
        // descendDelta 小 → vy が threshold 未満
        let result = feedSwingThenStop(detector, startTime: 0, startY: 0.1, descendDelta: 0.01)
        XCTAssertNil(result.event)
    }

    func testCooldownSuppressesSecondPunch() {
        // 1スイング＋停止シーケンスは約0.7s要するため、クールダウンを十分長くして
        // 2回目を確実にクールダウン窓内に収める。
        var config = GameConfig.default
        config.punchCooldown = 10
        let detector = HandSwingDetector(config: config)
        let first = feedSwingThenStop(detector, startTime: 0, startY: 0.1)
        XCTAssertNotNil(first.event)
        // クールダウン窓内で即座に2回目のスイング
        let second = feedSwingThenStop(detector, startTime: first.endTime + dt, startY: first.endY)
        XCTAssertNil(second.event, "クールダウン中は成立しないはず")
    }

    func testDetectionGapDuringSwingFinalizesPunch() {
        // 振り下ろし中に検出が途切れる（叩いた瞬間に手がブレて見失う）→ 再検出時に着地として成立
        let detector = HandSwingDetector(config: .default)
        var t = 0.0
        var y: CGFloat = 0.1
        for _ in 0..<6 { // 下降してスイング状態に
            detector.process(.init(screenPoint: CGPoint(x: 0.5, y: y), timestamp: t, confidence: 0.9))
            t += dt
            y += 0.5
        }
        // 大きなギャップ後に再検出
        let gap = GameConfig.default.maxSampleGap + 0.1
        let event = detector.process(.init(screenPoint: CGPoint(x: 0.5, y: y), timestamp: t + gap, confidence: 0.9))
        XCTAssertNotNil(event, "検出ギャップ＝着地として台パン成立")
    }

    func testDetectionGapWithoutSwingDoesNotTrigger() {
        let detector = HandSwingDetector(config: .default)
        detector.process(.init(screenPoint: CGPoint(x: 0.5, y: 0.5), timestamp: 0, confidence: 0.9))
        let gap = GameConfig.default.maxSampleGap + 0.1
        let event = detector.process(.init(screenPoint: CGPoint(x: 0.5, y: 0.5), timestamp: gap, confidence: 0.9))
        XCTAssertNil(event, "スイングしていなければギャップでも成立しない")
    }

    func testHandLostResetsSwing() {
        let detector = HandSwingDetector(config: .default)
        // 下降のみ流してスイング状態にする
        var t = 0.0
        var y: CGFloat = 0.1
        for _ in 0..<6 {
            detector.process(.init(screenPoint: CGPoint(x: 0.5, y: y), timestamp: t, confidence: 0.9))
            t += dt
            y += 0.5
        }
        detector.handLost()
        // 停止サンプルを流しても、ピークがリセットされ成立しない
        var event: TablePunchEvent?
        for _ in 0..<8 {
            if let e = detector.process(.init(screenPoint: CGPoint(x: 0.5, y: y), timestamp: t, confidence: 0.9)) {
                event = e
            }
            t += dt
        }
        XCTAssertNil(event)
    }
}
