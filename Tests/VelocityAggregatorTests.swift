import XCTest
import simd
import RealityKit
@testable import TableBangConcentration

final class VelocityAggregatorTests: XCTestCase {
    func testReturnsZeroForRestingCards() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        let speeds = VelocityAggregator.maxSpeeds(cards: manager.cards)
        XCTAssertEqual(speeds.linear, 0, accuracy: 1e-6)
        XCTAssertEqual(speeds.angular, 0, accuracy: 1e-6)
    }

    func testReturnsMaxAcrossCards() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        // 1枚に線形速度、別の1枚に角速度を与える
        manager.cards[0].physicsMotion?.linearVelocity = SIMD3<Float>(0, 0, 3)
        manager.cards[1].physicsMotion?.angularVelocity = SIMD3<Float>(0, 4, 0)

        let speeds = VelocityAggregator.maxSpeeds(cards: manager.cards)
        XCTAssertEqual(speeds.linear, 3, accuracy: 1e-5)
        XCTAssertEqual(speeds.angular, 4, accuracy: 1e-5)
    }

    func testEmptyCardsYieldsZero() {
        let speeds = VelocityAggregator.maxSpeeds(cards: [])
        XCTAssertEqual(speeds.linear, 0)
        XCTAssertEqual(speeds.angular, 0)
    }
}
