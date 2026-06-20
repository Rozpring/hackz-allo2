import XCTest
@testable import TableBangConcentration

final class GameStateManagerTests: XCTestCase {
    private func makeManager(timeLimit: Int = 90) -> GameStateManager {
        var config = GameConfig.default
        config.timeLimitSeconds = timeLimit
        config.scorePerPair = 100
        config.comboMultiplierStep = 0.5
        return GameStateManager(config: config)
    }

    func testStartsInPlacingPhase() {
        XCTAssertEqual(makeManager().phase, .placing)
    }

    func testStartPlayingSetsTimerAndPhase() {
        let manager = makeManager(timeLimit: 60)
        manager.startPlaying()
        XCTAssertEqual(manager.phase, .playing)
        XCTAssertEqual(manager.remainingSeconds, 60)
    }

    func testSinglePairScoresBasePoints() {
        let manager = makeManager()
        manager.startPlaying()
        manager.onPairsMatched(1, remainingPairs: 7)
        XCTAssertEqual(manager.score, 100)
    }

    func testMultiplePairsInOneSettleApplyComboMultiplier() {
        let manager = makeManager()
        manager.startPlaying()
        // 2ペア同時: 倍率 = 1 + (2-1)*0.5 = 1.5 → 2*100*1.5 = 300
        manager.onPairsMatched(2, remainingPairs: 6)
        XCTAssertEqual(manager.score, 300)
        XCTAssertEqual(manager.combo, 2)
    }

    func testNoPairResetsCombo() {
        let manager = makeManager()
        manager.startPlaying()
        manager.onPairsMatched(2, remainingPairs: 6)
        manager.onPairsMatched(0, remainingPairs: 6)
        XCTAssertEqual(manager.combo, 0)
        XCTAssertEqual(manager.score, 300, "未成立はスコア不変")
    }

    func testClearsWhenNoPairsRemain() {
        let manager = makeManager()
        manager.startPlaying()
        manager.onPairsMatched(1, remainingPairs: 0)
        XCTAssertEqual(manager.phase, .clear)
    }

    func testTimeUpWhenTimerReachesZero() {
        let manager = makeManager(timeLimit: 2)
        manager.startPlaying()
        manager.tick()
        XCTAssertEqual(manager.phase, .playing)
        manager.tick()
        XCTAssertEqual(manager.remainingSeconds, 0)
        XCTAssertEqual(manager.phase, .timeUp)
    }

    func testTickDoesNotGoNegativeOrOverrideClear() {
        let manager = makeManager(timeLimit: 1)
        manager.startPlaying()
        manager.onPairsMatched(1, remainingPairs: 0) // clear
        manager.tick()
        XCTAssertEqual(manager.phase, .clear, "クリア後は時間切れに上書きされない")
    }

    func testNoScoreAfterTimeUp() {
        // ゲームオーバー後はフレームが届いてもスコア加算・フェーズ遷移しない（HIGH-1）
        let manager = makeManager(timeLimit: 1)
        manager.startPlaying()
        manager.tick() // timeUp
        XCTAssertEqual(manager.phase, .timeUp)
        manager.onPairsMatched(2, remainingPairs: 0)
        XCTAssertEqual(manager.score, 0, "タイムアップ後は加点されない")
        XCTAssertEqual(manager.phase, .timeUp, "タイムアップからクリアへ不正遷移しない")
    }

    func testRecordPowerUpdatesLastPower() {
        let manager = makeManager()
        manager.recordPower(0.7)
        XCTAssertEqual(manager.lastPower, 0.7, accuracy: 1e-6)
    }

    func testRetryResetsState() {
        let manager = makeManager()
        manager.startPlaying()
        manager.onPairsMatched(2, remainingPairs: 6)
        manager.retry()
        XCTAssertEqual(manager.score, 0)
        XCTAssertEqual(manager.combo, 0)
        XCTAssertEqual(manager.phase, .placing)
    }
}
