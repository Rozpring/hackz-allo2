/// 物理静止後、表になっている全カードを走査し、同一ランク2枚の組（ペア）をすべて検出する。
///
/// - 入力は全カードでも表カードのみでもよい（内部で `isFaceUp` を見て表だけを対象にする）。
/// - 相手が表に揃っていないカードはペアに含めない（＝表のまま盤面に残す。要件 6.5 / 7.4）。
/// - 1回の走査で複数ペアが同時成立しうる（要件 6.3）。
/// - デッキは各ランクちょうど2枚（要件 6.1）。万一同一ランクが2枚を超えても、防御的に2枚ずつ組にする。
///
/// 設計対応: design.md `MatchEvaluator`。要件 6.1, 6.2, 6.3, 6.5, 7.4。
public struct MatchEvaluator {
    public init() {}

    /// 同一ランクが表で2枚揃う組をすべて返す。各組は2枚。
    public func findPairs<C: MatchableCard>(in cards: [C]) -> [[C]] {
        // ランクごとに表カードを安定順で集約。
        var byRank: [Int: [C]] = [:]
        var rankOrder: [Int] = []
        for card in cards where card.isFaceUp {
            if byRank[card.rank] == nil {
                rankOrder.append(card.rank)
            }
            byRank[card.rank, default: []].append(card)
        }

        // 各ランクで2枚ずつ組にする（通常は0組か1組）。
        var pairs: [[C]] = []
        for rank in rankOrder {
            guard let group = byRank[rank] else { continue }
            var index = 0
            while index + 1 < group.count {
                pairs.append([group[index], group[index + 1]])
                index += 2
            }
        }
        return pairs
    }
}
