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

/// raycast 投影のスパイ（固定ワールド点を返す）。
private final class SpyProjector: ScreenToWorldProjecting {
    let world: SIMD3<Float>?
    private(set) var lastScreenPoint: CGPoint?
    init(world: SIMD3<Float>?) { self.world = world }
    func worldPoint(fromScreen point: CGPoint) -> SIMD3<Float>? {
        lastScreenPoint = point
        return world
    }
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

    func testPunchProjectsAndEmitsShockwaveWithPower() {
        let config = GameConfig.default
        let provider = MockHandProvider()
        let projector = SpyProjector(world: SIMD3<Float>(1, 0, 2))
        let shock = SpyShockwave()
        let cardManager = CardManager()
        cardManager.buildBoard(config: config)
        let settle = PhysicsSettleObserver(cardManager: cardManager, config: config)
        let game = GameStateManager(config: config)
        let session = GameSession(
            handProvider: provider,
            swingDetector: HandSwingDetector(config: config),
            powerCalculator: PowerCalculator(config: config),
            projector: projector,
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
        XCTAssertEqual(shock.lastCenter, SIMD3<Float>(1, 0, 2), "raycast 投影点が衝撃波中心")
        XCTAssertGreaterThan(game.lastPower, 0, "威力が算出され記録される")
    }

    func testPunchOffPlaneDoesNotEmit() {
        let config = GameConfig.default
        let provider = MockHandProvider()
        let projector = SpyProjector(world: nil) // 平面外
        let shock = SpyShockwave()
        let cardManager = CardManager()
        cardManager.buildBoard(config: config)
        let settle = PhysicsSettleObserver(cardManager: cardManager, config: config)
        let game = GameStateManager(config: config)
        let session = GameSession(
            handProvider: provider,
            swingDetector: HandSwingDetector(config: config),
            powerCalculator: PowerCalculator(config: config),
            projector: projector,
            shockwave: shock,
            settleObserver: settle,
            cardManager: cardManager,
            matchEvaluator: MatchEvaluator(),
            gameState: game,
            dispatcher: SyncDispatcher()
        )
        session.start()
        feedPunch(provider)

        XCTAssertEqual(shock.emitCount, 0, "平面外への投影は衝撃波を発生させない（R4-4）")
    }

    func testBoardSettledCollectsMatchedPairAndScores() {
        let config = GameConfig.default
        let provider = MockHandProvider()
        let projector = SpyProjector(world: SIMD3<Float>(0, 0, 0))
        let shock = SpyShockwave()
        let cardManager = CardManager()
        cardManager.buildBoard(config: config)
        let settle = PhysicsSettleObserver(cardManager: cardManager, config: config)
        let game = GameStateManager(config: config)
        let session = GameSession(
            handProvider: provider,
            swingDetector: HandSwingDetector(config: config),
            powerCalculator: PowerCalculator(config: config),
            projector: projector,
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

        // 同一ランクの2枚を表向き姿勢にする（物理結果のシミュレート）
        let targetRank = cardManager.cards[0].rank
        let upright = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        cardManager.cards.filter { $0.rank == targetRank }.forEach { $0.orientation = upright }

        // 台パン → 静止確定（boardSettled）
        settle.onShockEmitted()
        for _ in 0..<config.settleFrameCount {
            session.onFrameTick() // 静止カードなので速度0 → 静止確定
        }

        XCTAssertEqual(game.score, config.scorePerPair, "成立した1ペア分が加点される")
        XCTAssertEqual(cardManager.remainingPairs, initialPairs - 1, "成立ペアは回収される")
        XCTAssertFalse(cardManager.cards.contains { $0.rank == targetRank }, "回収ランクは盤面から消える")
    }
}
