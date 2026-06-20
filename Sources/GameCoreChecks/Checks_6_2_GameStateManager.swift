import Foundation
import GameCore

private struct TestScoringConfig: ScoringConfig {
    var pairCount: Int = 3
    var timeLimitSeconds: Int = 5
    var basePairScore: Int = 100
    var comboMultiplierStep: Float = 0.5
}

private struct TestCard: MatchableCard {
    let id: Int
    let rank: Int
    var isFaceUp: Bool
}

private func faceUpPair(_ rank: Int, _ a: Int, _ b: Int) -> [TestCard] {
    [TestCard(id: a, rank: rank, isFaceUp: true), TestCard(id: b, rank: rank, isFaceUp: true)]
}

/// issue #26 (tasks 6.2): スコア・コンボ・残カード・制限時間・勝敗管理。
func runChecks_6_2() {
    section("#26 (6.2) GameStateManager 進行管理")
    let config = TestScoringConfig()

    // 1) 開始状態
    do {
        let gm = GameStateManager(config: config)
        gm.startGame()
        check(gm.phase == .playing, "startGame で playing に遷移")
        check(gm.remainingSeconds == 5, "残時間が制限時間で初期化")
        check(gm.remainingPairs == 3, "残ペアが pairCount で初期化")
        check(gm.score == 0 && gm.combo == 0, "スコア・コンボが0")
    }

    // 2) 単独ペアで加点（combo=1, multiplier=1.0）
    do {
        let gm = GameStateManager(config: config)
        gm.startGame()
        let pairs = gm.onBoardSettled(faceUpCards: faceUpPair(3, 1, 2))
        check(pairs.count == 1, "1ペア回収を返す")
        check(gm.score == 100, "基礎点100×1×倍率1.0 = 100 (got \(gm.score))")
        check(gm.combo == 1, "combo=1")
        check(gm.remainingPairs == 2, "残ペアが1減る")
    }

    // 3) 同時2ペアで加点（k=2, combo=1, multiplier=1.0 → 200）
    do {
        let gm = GameStateManager(config: config)
        gm.startGame()
        let cards = faceUpPair(3, 1, 2) + faceUpPair(7, 3, 4)
        gm.onBoardSettled(faceUpCards: cards)
        check(gm.score == 200, "同時2ペア: 100×2×1.0 = 200 (got \(gm.score))")
        check(gm.combo == 1, "1回の確定なので combo=1")
        check(gm.remainingPairs == 1, "残ペアが2減る")
    }

    // 4) 連続得点でコンボ倍率が上がる
    do {
        let gm = GameStateManager(config: TestScoringConfig(pairCount: 5, timeLimitSeconds: 30, basePairScore: 100, comboMultiplierStep: 0.5))
        gm.startGame()
        gm.onBoardSettled(faceUpCards: faceUpPair(3, 1, 2))   // combo1: 100×1×1.0 = 100
        check(gm.score == 100, "1回目 combo1 → 100 (got \(gm.score))")
        gm.onBoardSettled(faceUpCards: faceUpPair(7, 3, 4))   // combo2: 100×1×1.5 = 150
        check(gm.combo == 2, "連続得点で combo=2")
        check(gm.score == 250, "2回目 combo2(×1.5) → +150 = 250 (got \(gm.score))")
    }

    // 5) 0ペアの確定でコンボが途切れる
    do {
        let gm = GameStateManager(config: TestScoringConfig(pairCount: 5, timeLimitSeconds: 30, basePairScore: 100, comboMultiplierStep: 0.5))
        gm.startGame()
        gm.onBoardSettled(faceUpCards: faceUpPair(3, 1, 2))   // combo1
        let single = [TestCard(id: 9, rank: 9, isFaceUp: true)] // 相手未表 → 0ペア
        gm.onBoardSettled(faceUpCards: single)
        check(gm.combo == 0, "0ペアの確定で combo がリセット")
        check(gm.score == 100, "0ペアなので加点なし")
    }

    // 6) 全ペアクリアで clear
    do {
        let gm = GameStateManager(config: TestScoringConfig(pairCount: 2, timeLimitSeconds: 30, basePairScore: 100, comboMultiplierStep: 0.5))
        gm.startGame()
        gm.onBoardSettled(faceUpCards: faceUpPair(3, 1, 2) + faceUpPair(7, 3, 4)) // 2ペア=全部
        check(gm.remainingPairs == 0, "残ペア0")
        check(gm.phase == .clear, "全ペアクリアで clear")
    }

    // 7) 時間切れで timeUp、以降の確定は無視
    do {
        let gm = GameStateManager(config: TestScoringConfig(pairCount: 3, timeLimitSeconds: 2, basePairScore: 100, comboMultiplierStep: 0.5))
        gm.startGame()
        gm.tickSecond()
        check(gm.phase == .playing && gm.remainingSeconds == 1, "1秒経過で残1・playing維持")
        gm.tickSecond()
        check(gm.phase == .timeUp && gm.remainingSeconds == 0, "0秒で timeUp")
        let pairs = gm.onBoardSettled(faceUpCards: faceUpPair(3, 1, 2))
        check(pairs.isEmpty && gm.score == 0, "timeUp 後の確定は無視（加点なし）")
    }

    // 8) リトライで初期化
    do {
        let gm = GameStateManager(config: config)
        gm.startGame()
        gm.onBoardSettled(faceUpCards: faceUpPair(3, 1, 2))
        gm.retry()
        check(gm.phase == .placing, "retry で placing へ")
        check(gm.score == 0 && gm.combo == 0, "スコア・コンボ初期化")
    }

    // 9) 直近威力の記録
    do {
        let gm = GameStateManager(config: config)
        gm.startGame()
        gm.recordPunch(power: 0.8)
        check(gm.lastPower == 0.8, "recordPunch で lastPower 更新（HUD用）")
    }
}
