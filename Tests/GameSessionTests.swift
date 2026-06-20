import XCTest
import Combine
import CoreGraphics
import simd
import ARKit
@testable import TableBangConcentration

/// 任意の HandSample を流せるモック手検出プロバイダ。
private final class MockHandProvider: HandLandmarkProvider {
    private let subject = PassthroughSubject<HandSample, Never>()
    var samples: AnyPublisher<HandSample, Never> { subject.eraseToAnyPublisher() }
    func process(frame: ARFrame, interfaceOrientation: UIInterfaceOrientation) {}
    func send(_ sample: HandSample) { subject.send(sample) }
}

/// 衝撃波発生のスパイ。
private final class SpyShockwave: ShockwaveEmitting {
    private(set) var emitCount = 0
    private(set) var lastCenter: SIMD3<Float>?
    private(set) var lastPower: Float?
    func emit(at center: SIMD3<Float>, power: Float) {
        emitCount += 1
        lastCenter = center
        lastPower = power
    }
}

/// 同期ディスパッチ（テストでイベントを即時処理させる）。
private struct SyncDispatcher: Dispatching {
    func dispatch(_ work: @escaping () -> Void) { work() }
}

final class GameSessionTests: XCTestCase {
    private let dt = 0.05

    private func feedPunch(_ provider: MockHandProvider) {
        var t = 0.0
        var y: CGFloat = 0.1
        for _ in 0..<6 { // 下降
            provider.send(HandSample(screenPoint: CGPoint(x: 0.5, y: y), timestamp: t, confidence: 0.9))
            t += dt
            y += 0.5
        }
        for _ in 0..<8 { // 停止（着地）
            provider.send(HandSample(screenPoint: CGPoint(x: 0.5, y: y), timestamp: t, confidence: 0.9))
            t += dt
        }
    }

    func testPunchEmitsShockwaveAtBoardCenterWithPower() {
        let config = GameConfig.default
        let provider = MockHandProvider()
        let shock = SpyShockwave()
        let cardManager = CardManager()
        cardManager.buildBoard(config: config)
        cardManager.root.position = SIMD3<Float>(0.1, -0.86, -0.8) // 机の上に置かれた盤面を再現
        let settle = PhysicsSettleObserver(cardManager: cardManager, config: config)
        let game = GameStateManager(config: config)
        let session = GameSession(
            handProvider: provider,
            swingDetector: HandSwingDetector(config: config),
            powerCalculator: PowerCalculator(config: config),
            shockwave: shock,
            settleObserver: settle,
            cardManager: cardManager,
            matchEvaluator: MatchEvaluator(),
            gameState: game,
            dispatcher: SyncDispatcher()
        )
        session.start()
        game.startPlaying(totalPairs: cardManager.remainingPairs)

        feedPunch(provider)

        XCTAssertEqual(shock.emitCount, 1, "台パン成立で衝撃波が1回発生")
        XCTAssertEqual(shock.lastCenter, cardManager.boardCenterWorld, "衝撃波の中心は盤面（#59: 手raycastではなく盤面中心）")
        XCTAssertGreaterThan(game.lastPower, 0, "威力が算出され記録される")
        XCTAssertEqual(game.turns, 1, "台パン1回＝1ターン")
    }

    func testBoardSettledCollectsMatchedPairAndScores() {
        let config = GameConfig.default
        let provider = MockHandProvider()
        let shock = SpyShockwave()
        let cardManager = CardManager()
        cardManager.buildBoard(config: config)
        let settle = PhysicsSettleObserver(cardManager: cardManager, config: config)
        let game = GameStateManager(config: config)
        let session = GameSession(
            handProvider: provider,
            swingDetector: HandSwingDetector(config: config),
            powerCalculator: PowerCalculator(config: config),
            shockwave: shock,
            settleObserver: settle,
            cardManager: cardManager,
            matchEvaluator: MatchEvaluator(),
            gameState: game,
            dispatcher: SyncDispatcher()
        )
        session.start()
        game.startPlaying(totalPairs: cardManager.remainingPairs)
        let initialPairs = cardManager.remainingPairs

        // 同一 matchKey（同ランク＋同色）の2枚を表向き姿勢にする（物理結果のシミュレート）
        let targetKey = cardManager.cards[0].matchKey
        let upright = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        let pairCards = cardManager.cards.filter { $0.matchKey == targetKey }
        XCTAssertEqual(pairCards.count, 2)
        pairCards.forEach { $0.orientation = upright }

        // 台パン → 静止確定（boardSettled）
        settle.onShockEmitted()
        for _ in 0..<config.settleFrameCount {
            session.onFrameTick() // 静止カードなので速度0 → 静止確定
        }

        XCTAssertEqual(game.score, config.scorePerPair, "成立した1ペア分が加点される")
        XCTAssertEqual(cardManager.remainingPairs, initialPairs - 1, "成立ペアは回収される")
        XCTAssertFalse(cardManager.cards.contains { $0.matchKey == targetKey }, "回収ペアは盤面から消える")
    }
}
