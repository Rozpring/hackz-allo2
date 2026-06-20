import Foundation
import Combine
import RealityKit
import ARKit

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
    private let feedback: FeedbackController
    private let session: GameSession

    private var cancellables: Set<AnyCancellable> = []
    private var timer: AnyCancellable?
    private var boardAnchor: AnchorEntity?

    @Published private(set) var phase: GamePhase = .placing
    /// 手検出の有無（HUD の補助ガイド表示に使う, 要件 9.4）。
    @Published private(set) var isHandDetected: Bool = false

    /// クリア時の経過秒数（結果画面に渡す）。
    var elapsedSeconds: Int { config.timeLimitSeconds - gameState.remainingSeconds }

    init(config: GameConfig = .default) {
        self.config = config
        let scene = ARSceneController(config: config)
        let cardManager = CardManager()
        let gameState = GameStateManager(config: config)
        let settleObserver = PhysicsSettleObserver(cardManager: cardManager, config: config)
        let swingDetector = HandSwingDetector(config: config)
        let handProvider = VisionHandProvider()
        let feedback = FeedbackController()
        let session = GameSession(
            handProvider: handProvider,
            swingDetector: swingDetector,
            powerCalculator: PowerCalculator(config: config),
            projector: scene,
            shockwave: ShockwaveSystem(cardManager: cardManager, config: config),
            settleObserver: settleObserver,
            cardManager: cardManager,
            matchEvaluator: MatchEvaluator(),
            gameState: gameState,
            feedback: feedback
        )

        self.scene = scene
        self.cardManager = cardManager
        self.gameState = gameState
        self.settleObserver = settleObserver
        self.swingDetector = swingDetector
        self.handProvider = handProvider
        self.feedback = feedback
        self.session = session

        // カメラ1フィードを手検出＋静止監視へ分配（#30）。
        scene.frameConsumer = session
        session.start()

        gameState.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.phase = $0 }
            .store(in: &cancellables)

        // 手検出の有無を HUD ガイド用に反映（要件 9.4）。
        handProvider.samples
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.isHandDetected = true }
            .store(in: &cancellables)
    }

    /// 盤面を配置してプレイ開始（タイマ起動, R8-1）。
    /// MVP は中央前方に固定アンカーを置く（平面タップ配置は `scene.placeBoardAnchor` を利用）。
    func placeBoardAndStart() {
        // 既存アンカーを除去してから再配置（リトライ時のゴーストアンカー累積防止）。
        if let existing = boardAnchor {
            scene.arView.scene.removeAnchor(existing)
        }
        let anchor = AnchorEntity(world: SIMD3<Float>(0, -0.1, -0.5))
        scene.arView.scene.addAnchor(anchor)
        boardAnchor = anchor
        cardManager.attach(to: anchor)
        cardManager.buildBoard(config: config)
        gameState.startPlaying(totalPairs: cardManager.remainingPairs)
        startTimer()
    }

    /// 結果画面からのリトライ（初期状態へ, R8-4）。盤面再構築は次の `placeBoardAndStart()` で行う。
    func retry() {
        timer?.cancel()
        gameState.retry()
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.gameState.tick() }
    }
}
