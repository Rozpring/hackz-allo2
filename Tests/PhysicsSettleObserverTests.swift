import XCTest
import Combine
import simd
@testable import TableBangConcentration

final class PhysicsSettleObserverTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    private func makeConfig(frames: Int) -> GameConfig {
        var c = GameConfig.default
        c.settleFrameCount = frames
        return c
    }

    func testNotifiesAndConfirmsFacingOnSettle() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        let observer = PhysicsSettleObserver(cardManager: manager, config: makeConfig(frames: 2))

        var settledCount = 0
        observer.boardSettled.sink { settledCount += 1 }.store(in: &cancellables)

        observer.onShockEmitted()
        observer.update(maxLinearSpeed: 0, maxAngularSpeed: 0)
        observer.update(maxLinearSpeed: 0, maxAngularSpeed: 0)

        XCTAssertEqual(settledCount, 1)
        // 全カードが表裏確定済み（伏せ初期姿勢のまま → faceDown 確定）かつ疑似スリープ
        XCTAssertTrue(manager.cards.allSatisfy { $0.state == .faceDown })
        XCTAssertTrue(manager.cards.allSatisfy { $0.physicsBody?.mode == .static })
    }

    func testDoesNotNotifyBeforeShock() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        let observer = PhysicsSettleObserver(cardManager: manager, config: makeConfig(frames: 1))

        var settledCount = 0
        observer.boardSettled.sink { settledCount += 1 }.store(in: &cancellables)

        observer.update(maxLinearSpeed: 0, maxAngularSpeed: 0)
        XCTAssertEqual(settledCount, 0, "台パン前は静止監視しない")
    }

    func testWatchdogForcesSettleWhenNeverQuiet() {
        let manager = CardManager()
        manager.buildBoard(config: .default)
        let observer = PhysicsSettleObserver(
            cardManager: manager,
            config: makeConfig(frames: 8),
            watchdogFrames: 5
        )

        var settledCount = 0
        observer.boardSettled.sink { settledCount += 1 }.store(in: &cancellables)

        observer.onShockEmitted()
        // 一度も静止しなくてもウォッチドッグで確定（クラッシュせず継続, R10-4）
        for _ in 0..<5 {
            observer.update(maxLinearSpeed: 10, maxAngularSpeed: 10)
        }
        XCTAssertEqual(settledCount, 1)
    }
}
