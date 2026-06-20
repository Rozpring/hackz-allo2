import Foundation
import GameCore

private struct TestCard: MatchableCard {
    let id: Int
    let rank: Int
    var isFaceUp: Bool
}

/// issue #25 (tasks 6.1): 表カードの同一ランクペア自動検出。
func runChecks_6_1() {
    section("#25 (6.1) MatchEvaluator ペア検出")
    let evaluator = MatchEvaluator()

    // ヘルパ: 検出ペアをランク集合に変換
    func pairRanks<C: MatchableCard>(_ pairs: [[C]]) -> [Int] {
        pairs.compactMap { $0.first?.rank }.sorted()
    }

    // 1) 単独成立
    do {
        let cards = [
            TestCard(id: 1, rank: 3, isFaceUp: true),
            TestCard(id: 2, rank: 3, isFaceUp: true),
            TestCard(id: 3, rank: 5, isFaceUp: false),
        ]
        let pairs = evaluator.findPairs(in: cards)
        check(pairs.count == 1, "表で揃った1ランクが1ペア検出される (got \(pairs.count))")
        check(pairs.first?.count == 2, "ペアはちょうど2枚")
        check(Set(pairs.first?.map(\.id) ?? []) == [1, 2], "正しい2枚(id 1,2)が組になる")
    }

    // 2) 複数ペア同時成立
    do {
        let cards = [
            TestCard(id: 1, rank: 3, isFaceUp: true),
            TestCard(id: 2, rank: 3, isFaceUp: true),
            TestCard(id: 3, rank: 7, isFaceUp: true),
            TestCard(id: 4, rank: 7, isFaceUp: true),
            TestCard(id: 5, rank: 9, isFaceUp: true),
            TestCard(id: 6, rank: 9, isFaceUp: true),
        ]
        let pairs = evaluator.findPairs(in: cards)
        check(pairs.count == 3, "3ランクが同時に揃うと3ペア検出 (got \(pairs.count))")
        check(pairRanks(pairs) == [3, 7, 9], "検出ランクが {3,7,9}")
    }

    // 3) 相手が表に揃っていないカードは未成立（除外）
    do {
        let cards = [
            TestCard(id: 1, rank: 3, isFaceUp: true),   // 相手(rank3)は伏せ
            TestCard(id: 2, rank: 3, isFaceUp: false),
            TestCard(id: 3, rank: 8, isFaceUp: true),   // これは揃う
            TestCard(id: 4, rank: 8, isFaceUp: true),
        ]
        let pairs = evaluator.findPairs(in: cards)
        check(pairs.count == 1, "相手が伏せのランクは成立せず、揃ったランクのみ1ペア (got \(pairs.count))")
        check(pairs.first?.first?.rank == 8, "成立したのは rank 8")
    }

    // 4) 伏せカードのみ/空 → 0ペア
    do {
        let allDown = [
            TestCard(id: 1, rank: 3, isFaceUp: false),
            TestCard(id: 2, rank: 3, isFaceUp: false),
        ]
        check(evaluator.findPairs(in: allDown).isEmpty, "全て伏せなら0ペア")
        check(evaluator.findPairs(in: [TestCard]()).isEmpty, "空入力なら0ペア")
    }

    // 5) 未成立混在: 揃うものだけ返す
    do {
        let cards = [
            TestCard(id: 1, rank: 1, isFaceUp: true),
            TestCard(id: 2, rank: 1, isFaceUp: true),   // 揃う
            TestCard(id: 3, rank: 2, isFaceUp: true),   // 単独表
            TestCard(id: 4, rank: 2, isFaceUp: false),
            TestCard(id: 5, rank: 4, isFaceUp: false),
            TestCard(id: 6, rank: 4, isFaceUp: false),
        ]
        let pairs = evaluator.findPairs(in: cards)
        check(pairRanks(pairs) == [1], "揃った rank 1 のみ成立、単独表や全伏せは除外")
    }
}
