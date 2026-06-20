import Foundation
import Combine
import RealityKit
import ARKit

/// Vision 実装（#20）が入るまでの無入力手検出プロバイダ。アプリ全体のグラフを成立させるためのプレースホルダ。
final class IdleHandProvider: HandLandmarkProvider {
    var samples: AnyPublisher<HandSample, Never> { Empty().eraseToAnyPublisher() }
    func process(frame: ARFrame, interfaceOrientation: UIInterfaceOrientation) {}
}

/// アプリのオブジェクトグラフ（AR・カード・物理・ゲーム状態・結線）を束ねるライフサイクル管理（#31, #32）。
/// 画面遷移は `gameState.phase` の変化を公開し、`AppCoordinator` が購読する。
final class GameEngine: ObservableObject {
    let config: GameConfig
    let scene: ARSceneController
    let cardManager: CardManager
    let gameState: GameStateManager

    private let settleObserver: PhysicsSettleObserver
    private let swingDetector: HandSwingDetector
    private let handProvider: HandLandmarkProvider
    private let session: GameSession

    private var cancellables: Set<AnyCancellable> = []
    private var timer: AnyCancellable?

    @Published private(set) var phase: GamePhase = .placing

    init(config: GameConfig = .default) {
        self.config = config
        let scene = ARSceneController(config: config)
        let cardManager = CardManager()
        let gameState = GameStateManager(config: config)
        let settleObserver = PhysicsSettleObserver(cardManager: cardManager, config: config)
        let swingDetector = HandSwingDetector(config: config)
        let handProvider = IdleHandProvider()
        let session = GameSession(
            handProvider: handProvider,
            swingDetector: swingDetector,
            powerCalculator: PowerCalculator(config: config),
            projector: scene,
            shockwave: ShockwaveSystem(cardManager: cardManager, config: config),
            settleObserver: settleObserver,
            cardManager: cardManager,
            matchEvaluator: MatchEvaluator(),
            gameState: gameState
        )

        self.scene = scene
        self.cardManager = cardManager
        self.gameState = gameState
        self.settleObserver = settleObserver
        self.swingDetector = swingDetector
        self.handProvider = handProvider
        self.session = session

        // カメラ1フィードを手検出＋静止監視へ分配（#30）。
        scene.frameConsumer = session
        session.start()

        gameState.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.phase = $0 }
            .store(in: &cancellables)
    }

    /// 盤面を配置してプレイ開始（タイマ起動, R8-1）。
    /// MVP は中央前方に固定アンカーを置く（平面タップ配置は `scene.placeBoardAnchor` を利用）。
    func placeBoardAndStart() {
        let anchor = AnchorEntity(world: SIMD3<Float>(0, -0.1, -0.5))
        scene.arView.scene.addAnchor(anchor)
        cardManager.attach(to: anchor)
        cardManager.buildBoard(config: config)
        gameState.startPlaying(totalPairs: cardManager.remainingPairs)
        startTimer()
    }

    /// 結果画面からのリトライ（盤面再構築・初期状態へ, R8-4）。
    func retry() {
        timer?.cancel()
        cardManager.buildBoard(config: config)
        gameState.retry()
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.gameState.tick() }
    }
}
