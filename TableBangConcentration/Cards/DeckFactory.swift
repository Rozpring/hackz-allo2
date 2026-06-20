import Foundation

/// 各ランクちょうど2枚ずつのデッキ（ランク列）を構築する（R2-3, R2-4）。
/// スートは判定に用いないため、カードはランク(Int)のみで表現する。
enum DeckFactory {
    /// `pairCount` ペア = `2 * pairCount` 枚。各ランクは 0..<pairCount に一意に対応し、必ず2枚ずつ。
    static func makeRanks(pairCount: Int, shuffled: Bool = true) -> [Int] {
        precondition(pairCount > 0, "pairCount must be positive")
        let ranks = (0..<pairCount).flatMap { [$0, $0] }
        return shuffled ? ranks.shuffled() : ranks
    }
}
