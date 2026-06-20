import Foundation

/// ペア判定に必要なカードの最小契約。`CardEntity` も準拠する（テスト容易性のため抽象化）。
protocol RankedCard: AnyObject {
    var rank: Int { get }
    var isFaceUp: Bool { get }
}

/// 表になっている全カードを走査し、同一ランク2枚の組をすべて検出する（R6-1〜R6-3, R6-5, R7-4）。
struct MatchEvaluator {
    /// 表カードのうち同一ランクが2枚揃う組を全て返す（複数同時可）。
    /// 相手が表に揃わないカードは結果に含めない（表のまま保持）。
    /// 各ランクはデッキ構成上2枚を超えないが、安全のため先頭2枚に限定する。
    func findPairs<C: RankedCard>(faceUp cards: [C]) -> [[C]] {
        let grouped = Dictionary(grouping: cards.filter { $0.isFaceUp }, by: { $0.rank })
        return grouped.values
            .filter { $0.count >= 2 }
            .map { Array($0.prefix(2)) }
    }
}
