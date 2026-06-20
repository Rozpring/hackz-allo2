import XCTest
@testable import TableBangConcentration

final class RestDetectorTests: XCTestCase {
    private func makeConfig(frames: Int) -> GameConfig {
        var c = GameConfig.default
        c.settleFrameCount = frames
        c.settleLinearThreshold = 0.02
        c.settleAngularThreshold = 0.05
        return c
    }

    func testSettlesAfterConsecutiveQuietFrames() {
        let detector = RestDetector(config: makeConfig(frames: 3))
        XCTAssertFalse(detector.update(maxLinearSpeed: 0.0, maxAngularSpeed: 0.0)) // 1
        XCTAssertFalse(detector.update(maxLinearSpeed: 0.0, maxAngularSpeed: 0.0)) // 2
        XCTAssertTrue(detector.update(maxLinearSpeed: 0.0, maxAngularSpeed: 0.0))  // 3 → 静止確定
    }

    func testFiresOnlyOnceUntilReset() {
        let detector = RestDetector(config: makeConfig(frames: 2))
        _ = detector.update(maxLinearSpeed: 0, maxAngularSpeed: 0)
        XCTAssertTrue(detector.update(maxLinearSpeed: 0, maxAngularSpeed: 0))
        XCTAssertFalse(detector.update(maxLinearSpeed: 0, maxAngularSpeed: 0), "確定後は再発火しない")
    }

    func testMotionResetsCounter() {
        let detector = RestDetector(config: makeConfig(frames: 3))
        _ = detector.update(maxLinearSpeed: 0, maxAngularSpeed: 0) // 1
        _ = detector.update(maxLinearSpeed: 0, maxAngularSpeed: 0) // 2
        XCTAssertFalse(detector.update(maxLinearSpeed: 1.0, maxAngularSpeed: 0), "速い動きでリセット")
        // 改めて3連続必要
        XCTAssertFalse(detector.update(maxLinearSpeed: 0, maxAngularSpeed: 0)) // 1
        XCTAssertFalse(detector.update(maxLinearSpeed: 0, maxAngularSpeed: 0)) // 2
        XCTAssertTrue(detector.update(maxLinearSpeed: 0, maxAngularSpeed: 0))  // 3
    }

    func testAngularMotionAlonePreventsSettle() {
        let detector = RestDetector(config: makeConfig(frames: 2))
        XCTAssertFalse(detector.update(maxLinearSpeed: 0, maxAngularSpeed: 1.0))
        XCTAssertFalse(detector.update(maxLinearSpeed: 0, maxAngularSpeed: 1.0))
    }

    func testExplicitResetRearmsDetector() {
        let detector = RestDetector(config: makeConfig(frames: 2))
        _ = detector.update(maxLinearSpeed: 0, maxAngularSpeed: 0)
        XCTAssertTrue(detector.update(maxLinearSpeed: 0, maxAngularSpeed: 0))
        detector.reset()
        XCTAssertFalse(detector.update(maxLinearSpeed: 0, maxAngularSpeed: 0))
        XCTAssertTrue(detector.update(maxLinearSpeed: 0, maxAngularSpeed: 0))
    }
}
