import XCTest
@testable import TableBangConcentration

final class GameStateManagerTests: XCTestCase {
    private func makeManager() -> GameStateManager {
        var config = GameConfig.default
        config.scorePerPair = 100
        config.comboMultiplierStep = 0.5
        return GameStateManager(config: config)
    }

    func testStartsInPlacingPhase() {
        XCTAssertEqual(makeManager().phase, .placing)
    }

    func testStartPlayingResetsTurnsAndPhase() {
        let manager = makeManager()
        manager.startPlaying(totalPairs: 8)
        XCTAssertEqual(manager.phase, .playing)
        XCTAssertEqual(manager.turns, 0)
        XCTAssertEqual(manager.remainingPairs, 8)
    }

    func testIncrementTurnCountsBangs() {
        let manager = makeManager()
        manager.startPlaying(totalPairs: 8)
        manager.incrementTurn()
        manager.incrementTurn()
        XCTAssertEqual(manager.turns, 2)
    }

    func testIncrementTurnIgnoredBeforePlaying() {
        let manager = makeManager()
        manager.incrementTurn() // placing 中は無視
        XCTAssertEqual(manager.turns, 0)
    }

    func testRemainingPairsTracksMatches() {
        let manager = makeManager()
        manager.startPlaying(totalPairs: 8)
        manager.onPairsMatched(2, remainingPairs: 6)
        XCTAssertEqual(manager.remainingPairs, 6)
        manager.onPairsMatched(1, remainingPairs: 5)
        XCTAssertEqual(manager.remainingPairs, 5)
    }

    func testSinglePairScoresBasePoints() {
        let manager = makeManager()
        manager.startPlaying(totalPairs: 8)
        manager.onPairsMatched(1, remainingPairs: 7)
        XCTAssertEqual(manager.score, 100)
    }

    func testMultiplePairsInOneSettleApplyComboMultiplier() {
        let manager = makeManager()
        manager.startPlaying(totalPairs: 8)
        // 2ペア同時: 倍率 = 1 + (2-1)*0.5 = 1.5 → 2*100*1.5 = 300
        manager.onPairsMatched(2, remainingPairs: 6)
        XCTAssertEqual(manager.score, 300)
        XCTAssertEqual(manager.combo, 2)
    }

    func testNoPairResetsCombo() {
        let manager = makeManager()
        manager.startPlaying(totalPairs: 8)
        manager.onPairsMatched(2, remainingPairs: 6)
        manager.onPairsMatched(0, remainingPairs: 6)
        XCTAssertEqual(manager.combo, 0)
        XCTAssertEqual(manager.score, 300, "未成立はスコア不変")
    }

    func testClearsWhenNoPairsRemain() {
        let manager = makeManager()
        manager.startPlaying(totalPairs: 8)
        manager.onPairsMatched(1, remainingPairs: 0)
        XCTAssertEqual(manager.phase, .clear)
    }

    func testNoScoreOrTurnAfterClear() {
        // クリア後はフレームが届いても加点・ターン加算しない
        let manager = makeManager()
        manager.startPlaying(totalPairs: 1)
        manager.onPairsMatched(1, remainingPairs: 0) // clear
        manager.incrementTurn()
        manager.onPairsMatched(2, remainingPairs: 0)
        XCTAssertEqual(manager.phase, .clear)
        XCTAssertEqual(manager.turns, 0, "クリア後はターン加算しない")
        XCTAssertEqual(manager.score, 100, "クリア後は加点しない")
    }

    func testRecordPowerUpdatesLastPower() {
        let manager = makeManager()
        manager.recordPower(0.7)
        XCTAssertEqual(manager.lastPower, 0.7, accuracy: 1e-6)
    }

    func testRetryResetsState() {
        let manager = makeManager()
        manager.startPlaying(totalPairs: 8)
        manager.incrementTurn()
        manager.onPairsMatched(2, remainingPairs: 6)
        manager.retry()
        XCTAssertEqual(manager.score, 0)
        XCTAssertEqual(manager.combo, 0)
        XCTAssertEqual(manager.turns, 0)
        XCTAssertEqual(manager.phase, .placing)
    }
}
