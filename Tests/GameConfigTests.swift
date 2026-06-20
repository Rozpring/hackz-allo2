import XCTest
import simd
@testable import TableBangConcentration

final class GameConfigTests: XCTestCase {
    func testDefaultIsConsistent() {
        let c = GameConfig.default
        XCTAssertEqual(c.pairCount, 8)
        XCTAssertEqual(c.gridColumns, 4)
        XCTAssertLessThan(c.minPower, c.maxPower)
        XCTAssertGreaterThan(c.radiusForMaxPower, c.radiusForMinPower)
        XCTAssertGreaterThan(c.velocityForMaxPower, c.swingVelocityThreshold)
        XCTAssertGreaterThan(c.settleFrameCount, 0)
    }

    func testCardIsThin() {
        let c = GameConfig.default
        // 厚み(y) が 幅(x)・奥行(z) より十分小さい薄い箱であること
        XCTAssertLessThan(c.cardSize.y, c.cardSize.x)
        XCTAssertLessThan(c.cardSize.y, c.cardSize.z)
    }
}
