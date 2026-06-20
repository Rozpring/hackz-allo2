import XCTest
import simd
import RealityKit
@testable import TableBangConcentration

final class CardManagerTests: XCTestCase {
    func testBuildBoardCreatesFullDeck() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        XCTAssertEqual(manager.cards.count, 52) // 標準52枚デッキ
    }

    func testEachMatchKeyExactlyTwice() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        let counts = Dictionary(grouping: manager.cards, by: { $0.matchKey }).mapValues(\.count)
        XCTAssertEqual(counts.count, 26, "26ペア")
        XCTAssertTrue(counts.values.allSatisfy { $0 == 2 })
    }

    func testRemainingPairsInitial() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        XCTAssertEqual(manager.remainingPairs, 26)
    }

    func testCardsWithinLargeRadiusIncludesAll() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        let within = manager.cards(within: 100, of: SIMD3<Float>(0, 0, 0))
        XCTAssertEqual(within.count, 52)
    }

    func testCardsWithinRadiusUsesWorldSpaceWhenAnchoredAwayFromOrigin() {
        // 盤面アンカーが机の上（ワールド原点から離れた位置）に置かれた状況を再現。
        // 中心は raycast 由来のワールド座標で渡る。ローカル座標と混同すると半径内カードが0になる（#59 の真因）。
        let manager = CardManager()
        manager.buildBoard(config: .default)
        manager.root.position = SIMD3<Float>(5, 0, 5)
        let worldCenter = manager.cards[0].position(relativeTo: nil)

        let within = manager.cards(within: 0.2, of: worldCenter)

        XCTAssertFalse(within.isEmpty, "ワールド座標の中心付近のカードが対象になる")
        XCTAssertTrue(within.contains { $0 === manager.cards[0] })
    }

    func testCardsWithinTinyRadiusFarFromBoardIsEmpty() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        let within = manager.cards(within: 0.001, of: SIMD3<Float>(10, 0, 10))
        XCTAssertTrue(within.isEmpty)
    }

    func testCollectingMatchedPairRemovesItAndDecrementsPairs() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        let targetKey = manager.cards[0].matchKey
        let pair = manager.cards.filter { $0.matchKey == targetKey }
        XCTAssertEqual(pair.count, 2, "各 matchKey は2枚")

        manager.collect(pair)

        XCTAssertEqual(manager.cards.count, 50)
        XCTAssertEqual(manager.remainingPairs, 25)
        XCTAssertTrue(pair.allSatisfy { $0.state == .collected })
        XCTAssertFalse(manager.cards.contains { $0.matchKey == targetKey }, "回収したペアは盤面から消える")
    }

    func testBuildBoardInstallsFloorAndWalls() {
        // 静的な床1枚＋外周4枚の不可視壁
        let manager = CardManager()
        manager.buildBoard(config: .default)
        XCTAssertEqual(manager.boundaries.count, 5)
    }
}
