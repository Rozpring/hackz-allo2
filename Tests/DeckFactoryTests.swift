import XCTest
@testable import TableBangConcentration

final class DeckFactoryTests: XCTestCase {
    func testTotalCountIsTwicePairs() {
        XCTAssertEqual(DeckFactory.makeRanks(pairCount: 8, shuffled: false).count, 16)
        XCTAssertEqual(DeckFactory.makeRanks(pairCount: 5).count, 10)
    }

    func testEachRankExactlyTwice() {
        for shuffled in [true, false] {
            let ranks = DeckFactory.makeRanks(pairCount: 8, shuffled: shuffled)
            let counts = Dictionary(grouping: ranks, by: { $0 }).mapValues(\.count)
            XCTAssertEqual(counts.count, 8, "shuffled=\(shuffled)")
            XCTAssertTrue(counts.values.allSatisfy { $0 == 2 }, "shuffled=\(shuffled)")
        }
    }
}
