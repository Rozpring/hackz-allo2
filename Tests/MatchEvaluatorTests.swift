import XCTest
@testable import TableBangConcentration

private final class MockCard: MatchableCard {
    let matchKey: Int
    var isFaceUp: Bool
    init(_ matchKey: Int, faceUp: Bool) {
        self.matchKey = matchKey
        self.isFaceUp = faceUp
    }
}

final class MatchEvaluatorTests: XCTestCase {
    private let evaluator = MatchEvaluator()

    func testDetectsMultipleSimultaneousPairs() {
        let cards = [
            MockCard(1, faceUp: true), MockCard(1, faceUp: true),
            MockCard(2, faceUp: true), MockCard(2, faceUp: true),
            MockCard(3, faceUp: true), // 相手未表
        ]
        let pairs = evaluator.findPairs(faceUp: cards)
        XCTAssertEqual(pairs.count, 2)
        XCTAssertTrue(pairs.allSatisfy { $0.count == 2 })
    }

    func testNoPartnerYieldsNoPair() {
        let cards = [MockCard(1, faceUp: true), MockCard(2, faceUp: true)]
        XCTAssertTrue(evaluator.findPairs(faceUp: cards).isEmpty)
    }

    func testIgnoresFaceDownCards() {
        let cards = [MockCard(1, faceUp: true), MockCard(1, faceUp: false)]
        XCTAssertTrue(evaluator.findPairs(faceUp: cards).isEmpty)
    }

    func testPairConsistsOfSameMatchKey() {
        let cards = [MockCard(7, faceUp: true), MockCard(7, faceUp: true)]
        let pairs = evaluator.findPairs(faceUp: cards)
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(Set(pairs[0].map(\.matchKey)), [7])
    }

    func testDifferentKeySameRankIsNotPair() {
        // 同ランクでも色違い（matchKey 異なる）は成立しない
        let cards = [MockCard(10, faceUp: true), MockCard(11, faceUp: true)]
        XCTAssertTrue(evaluator.findPairs(faceUp: cards).isEmpty)
    }
}
