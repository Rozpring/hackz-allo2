import XCTest
import simd
import RealityKit
@testable import TableBangConcentration

final class CardManagerTests: XCTestCase {
    func testBuildBoardCreatesTwicePairCountCards() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        XCTAssertEqual(manager.cards.count, 16) // pairCount 8 → 16枚
    }

    func testEachRankExactlyTwice() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        let counts = Dictionary(grouping: manager.cards, by: { $0.rank }).mapValues(\.count)
        XCTAssertEqual(counts.count, GameConfig.default.pairCount)
        XCTAssertTrue(counts.values.allSatisfy { $0 == 2 })
    }

    func testRemainingPairsInitial() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        XCTAssertEqual(manager.remainingPairs, 8)
    }

    func testCardsWithinLargeRadiusIncludesAll() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        let within = manager.cards(within: 100, of: SIMD3<Float>(0, 0, 0))
        XCTAssertEqual(within.count, 16)
    }

    func testCardsWithinTinyRadiusFarFromBoardIsEmpty() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        let within = manager.cards(within: 0.001, of: SIMD3<Float>(10, 0, 10))
        XCTAssertTrue(within.isEmpty)
    }

    func testCollectingSameRankPairRemovesItAndDecrementsPairs() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        let targetRank = manager.cards[0].rank
        let pair = manager.cards.filter { $0.rank == targetRank }
        XCTAssertEqual(pair.count, 2, "各ランクは2枚")

        manager.collect(pair)

        XCTAssertEqual(manager.cards.count, 14)
        XCTAssertEqual(manager.remainingPairs, 7)
        XCTAssertTrue(pair.allSatisfy { $0.state == .collected })
        XCTAssertFalse(manager.cards.contains { $0.rank == targetRank }, "回収したランクは盤面から消える")
    }

    func testBuildBoardInstallsFloorAndWalls() {
        // 静的な床1枚＋外周4枚の不可視壁
        let manager = CardManager()
        manager.buildBoard(config: .default)
        XCTAssertEqual(manager.boundaries.count, 5)
    }
}
