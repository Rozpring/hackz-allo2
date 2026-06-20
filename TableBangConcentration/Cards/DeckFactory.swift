import Foundation

/// トランプのスート。色（赤/黒）でペア判定に用いる。
enum Suit: CaseIterable, Equatable {
    case spades   // ♠ 黒
    case hearts   // ♥ 赤
    case diamonds // ♦ 赤
    case clubs    // ♣ 黒

    var symbol: String {
        switch self {
        case .spades: return "♠"
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        }
    }

    var isRed: Bool { self == .hearts || self == .diamonds }
}

/// 1枚のカードの論理表現（ランク 0..12 ＋ スート）。
struct Card: Equatable {
    let rank: Int
    let suit: Suit

    /// ペア判定キー: 同ランク＋同色で一致（A♠↔A♣, A♥↔A♦）。各キーはデッキ内にちょうど2枚（26ペア）。
    var matchKey: Int { rank * 2 + (suit.isRed ? 1 : 0) }
}

/// 標準52枚デッキ（13ランク×4スート）を構築する。ペアは同ランク＋同色で必ず成立可能（26ペア）。
enum DeckFactory {
    /// ランク数（A,2..10,J,Q,K）。
    static let rankCount = 13

    /// 13ランク×4スート＝52枚の標準デッキ。
    static func makeStandardDeck(shuffled: Bool = true) -> [Card] {
        let deck = Suit.allCases.flatMap { suit in
            (0..<rankCount).map { rank in Card(rank: rank, suit: suit) }
        }
        return shuffled ? deck.shuffled() : deck
    }
}
