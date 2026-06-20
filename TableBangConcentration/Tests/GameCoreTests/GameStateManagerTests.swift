import XCTest
import GameCore

private struct TestScoringConfig: ScoringConfig {
    var pairCount: Int
    var timeLimitSeconds: Int
    var basePairScore: Int
    var comboMultiplierStep: Float
    init(pairCount: Int = 3, timeLimitSeconds: Int = 5, basePairScore: Int = 100, comboMultiplierStep: Float = 0.5) {
        self.pairCount = pairCount; self.timeLimitSeconds = timeLimitSeconds
        self.basePairScore = basePairScore; self.comboMultiplierStep = comboMultiplierStep
    }
}

private struct TestCard: MatchableCard {
    let id: Int; let rank: Int; var isFaceUp: Bool
}

private func pair(_ rank: Int, _ a: Int, _ b: Int) -> [TestCard] {
    [TestCard(id: a, rank: rank, isFaceUp: true), TestCard(id: b, rank: rank, isFaceUp: true)]
}

final class GameStateManagerTests: XCTestCase {
    func testStartGameInitializes() {
        let gm = GameStateManager(config: TestScoringConfig())
        gm.startGame()
        XCTAssertEqual(gm.phase, .playing)
        XCTAssertEqual(gm.remainingSeconds, 5)
        XCTAssertEqual(gm.remainingPairs, 3)
    }

    func testSinglePairScore() {
        let gm = GameStateManager(config: TestScoringConfig())
        gm.startGame()
        let pairs = gm.onBoardSettled(faceUpCards: pair(3, 1, 2))
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(gm.score, 100)
        XCTAssertEqual(gm.combo, 1)
        XCTAssertEqual(gm.remainingPairs, 2)
    }

    func testSimultaneousTwoPairs() {
        let gm = GameStateManager(config: TestScoringConfig())
        gm.startGame()
        gm.onBoardSettled(faceUpCards: pair(3, 1, 2) + pair(7, 3, 4))
        XCTAssertEqual(gm.score, 200)
        XCTAssertEqual(gm.combo, 1)
    }

    func testComboMultiplierAcrossSettles() {
        let gm = GameStateManager(config: TestScoringConfig(pairCount: 5, timeLimitSeconds: 30))
        gm.startGame()
        gm.onBoardSettled(faceUpCards: pair(3, 1, 2))   // 100
        gm.onBoardSettled(faceUpCards: pair(7, 3, 4))   // +150 (×1.5)
        XCTAssertEqual(gm.combo, 2)
        XCTAssertEqual(gm.score, 250)
    }

    func testComboResetsOnZeroPairSettle() {
        let gm = GameStateManager(config: TestScoringConfig(pairCount: 5, timeLimitSeconds: 30))
        gm.startGame()
        gm.onBoardSettled(faceUpCards: pair(3, 1, 2))
        gm.onBoardSettled(faceUpCards: [TestCard(id: 9, rank: 9, isFaceUp: true)])
        XCTAssertEqual(gm.combo, 0)
        XCTAssertEqual(gm.score, 100)
    }

    func testClearWhenAllPairsCollected() {
        let gm = GameStateManager(config: TestScoringConfig(pairCount: 2, timeLimitSeconds: 30))
        gm.startGame()
        gm.onBoardSettled(faceUpCards: pair(3, 1, 2) + pair(7, 3, 4))
        XCTAssertEqual(gm.remainingPairs, 0)
        XCTAssertEqual(gm.phase, .clear)
    }

    func testTimeUpAndIgnoreAfterwards() {
        let gm = GameStateManager(config: TestScoringConfig(pairCount: 3, timeLimitSeconds: 2))
        gm.startGame()
        gm.tickSecond()
        gm.tickSecond()
        XCTAssertEqual(gm.phase, .timeUp)
        let pairs = gm.onBoardSettled(faceUpCards: pair(3, 1, 2))
        XCTAssertTrue(pairs.isEmpty)
        XCTAssertEqual(gm.score, 0)
    }

    func testRetryResets() {
        let gm = GameStateManager(config: TestScoringConfig())
        gm.startGame()
        gm.onBoardSettled(faceUpCards: pair(3, 1, 2))
        gm.retry()
        XCTAssertEqual(gm.phase, .placing)
        XCTAssertEqual(gm.score, 0)
    }
}
