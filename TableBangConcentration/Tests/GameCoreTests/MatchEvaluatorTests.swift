import XCTest
import GameCore

private struct TestCard: MatchableCard {
    let id: Int
    let rank: Int
    var isFaceUp: Bool
}

final class MatchEvaluatorTests: XCTestCase {
    private let evaluator = MatchEvaluator()

    private func pairRanks<C: MatchableCard>(_ pairs: [[C]]) -> [Int] {
        pairs.compactMap { $0.first?.rank }.sorted()
    }

    func testSinglePair() {
        let cards = [
            TestCard(id: 1, rank: 3, isFaceUp: true),
            TestCard(id: 2, rank: 3, isFaceUp: true),
            TestCard(id: 3, rank: 5, isFaceUp: false),
        ]
        let pairs = evaluator.findPairs(in: cards)
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(Set(pairs.first?.map(\.id) ?? []), [1, 2])
    }

    func testMultipleSimultaneousPairs() {
        let cards = [
            TestCard(id: 1, rank: 3, isFaceUp: true), TestCard(id: 2, rank: 3, isFaceUp: true),
            TestCard(id: 3, rank: 7, isFaceUp: true), TestCard(id: 4, rank: 7, isFaceUp: true),
            TestCard(id: 5, rank: 9, isFaceUp: true), TestCard(id: 6, rank: 9, isFaceUp: true),
        ]
        XCTAssertEqual(pairRanks(evaluator.findPairs(in: cards)), [3, 7, 9])
    }

    func testPartnerFaceDownExcluded() {
        let cards = [
            TestCard(id: 1, rank: 3, isFaceUp: true),
            TestCard(id: 2, rank: 3, isFaceUp: false),
            TestCard(id: 3, rank: 8, isFaceUp: true),
            TestCard(id: 4, rank: 8, isFaceUp: true),
        ]
        let pairs = evaluator.findPairs(in: cards)
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs.first?.first?.rank, 8)
    }

    func testEmptyAndAllFaceDown() {
        XCTAssertTrue(evaluator.findPairs(in: [TestCard]()).isEmpty)
        let allDown = [
            TestCard(id: 1, rank: 3, isFaceUp: false),
            TestCard(id: 2, rank: 3, isFaceUp: false),
        ]
        XCTAssertTrue(evaluator.findPairs(in: allDown).isEmpty)
    }
}
