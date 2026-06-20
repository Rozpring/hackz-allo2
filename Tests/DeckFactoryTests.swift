import XCTest
@testable import TableBangConcentration

final class DeckFactoryTests: XCTestCase {
    func testStandardDeckHas52Cards() {
        XCTAssertEqual(DeckFactory.makeStandardDeck(shuffled: false).count, 52)
    }

    func testEachRankHasFourSuits() {
        let deck = DeckFactory.makeStandardDeck(shuffled: false)
        let byRank = Dictionary(grouping: deck, by: { $0.rank })
        XCTAssertEqual(byRank.count, 13, "13ランク")
        XCTAssertTrue(byRank.values.allSatisfy { cards in
            Set(cards.map(\.suit)) == Set(Suit.allCases)
        }, "各ランクに4スート")
    }

    func testEachMatchKeyHasExactlyTwoCards() {
        // ペアは同ランク＋同色 → 各 matchKey はちょうど2枚（26ペア=52枚）
        let deck = DeckFactory.makeStandardDeck(shuffled: false)
        let byKey = Dictionary(grouping: deck, by: { $0.matchKey })
        XCTAssertEqual(byKey.count, 26, "26ペア")
        XCTAssertTrue(byKey.values.allSatisfy { $0.count == 2 })
    }

    func testMatchKeyPairsSameRankSameColor() {
        let aceSpades = Card(rank: 0, suit: .spades)
        let aceClubs = Card(rank: 0, suit: .clubs)
        let aceHearts = Card(rank: 0, suit: .hearts)
        XCTAssertEqual(aceSpades.matchKey, aceClubs.matchKey, "A♠とA♣は同色ペア")
        XCTAssertNotEqual(aceSpades.matchKey, aceHearts.matchKey, "A♠とA♥は色違いで非ペア")
    }
}
