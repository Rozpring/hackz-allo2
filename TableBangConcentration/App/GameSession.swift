import Foundation
import Combine
import UIKit
import ARKit

/// 状態更新を実行するスレッドの抽象。ARKit デリゲートはバックグラウンドのシリアルキューで配信されるため、
/// `@Published`/RealityKit 更新はメインへホップする。テストでは同期ディスパッチに差し替える。
protocol Dispatching {
    func dispatch(_ work: @escaping () -> Void)
}

/// 本番: メインキューへ非同期ディスパッチ。
struct MainDispatcher: Dispatching {
    func dispatch(_ work: @escaping () -> Void) { DispatchQueue.main.async(execute: work) }
}

/// 台パン1回のフローを1本に結線するオーケストレータ（#30, #31）。
///
/// 手検出サンプル → 振り下ろし速度 → 台パン成立 → 威力算出 → screen→plane 投影 →
/// 衝撃波 → 物理 → 静止確定 → ペア検出 → 回収/加点 までを接続する。
/// `ARFrameConsuming` としてカメラ1フィードを受け、手検出への分配と毎フレームの静止監視を行う。
final class GameSession: ARFrameConsuming {
    private let handProvider: HandLandmarkProvider
    private let swingDetector: HandSwingDetector
    private let powerCalculator: PowerCalculator
    private let shockwave: ShockwaveEmitting
    private let settleObserver: PhysicsSettleObserver
    private let cardManager: CardManaging
    private let matchEvaluator: MatchEvaluator
    private let gameState: GameStateManager
    private let feedback: FeedbackController?
    private let interfaceOrientationProvider: () -> UIInterfaceOrientation
    private let dispatcher: Dispatching

    private var cancellables: Set<AnyCancellable> = []

    init(
        handProvider: HandLandmarkProvider,
        swingDetector: HandSwingDetector,
        powerCalculator: PowerCalculator,
        shockwave: ShockwaveEmitting,
        settleObserver: PhysicsSettleObserver,
        cardManager: CardManaging,
        matchEvaluator: MatchEvaluator,
        gameState: GameStateManager,
        feedback: FeedbackController? = nil,
        interfaceOrientationProvider: @escaping () -> UIInterfaceOrientation = { .portrait },
        dispatcher: Dispatching = MainDispatcher()
    ) {
        self.handProvider = handProvider
        self.swingDetector = swingDetector
        self.powerCalculator = powerCalculator
        self.shockwave = shockwave
        self.settleObserver = settleObserver
        self.cardManager = cardManager
        self.matchEvaluator = matchEvaluator
        self.gameState = gameState
        self.feedback = feedback
        self.interfaceOrientationProvider = interfaceOrientationProvider
        self.dispatcher = dispatcher
    }

    /// 購読を開始する。ARKit 由来のイベントはメインへホップしてから状態を更新する（HIGH-2）。
    func start() {
        handProvider.samples
            .sink { [weak self] sample in
                self?.dispatcher.dispatch { self?.swingDetector.process(sample) }
            }
            .store(in: &cancellables)

        swingDetector.punches
            .sink { [weak self] punch in self?.handlePunch(punch) }
            .store(in: &cancellables)

        settleObserver.boardSettled
            .sink { [weak self] in self?.dispatcher.dispatch { self?.handleBoardSettled() } }
            .store(in: &cancellables)
    }

    // MARK: - ARFrameConsuming（カメラ1フィードの二系統分配, #30）

    func consume(frame: ARFrame) {
        // ① 手検出へ capturedImage を委譲（AR描画/物理は ARView 内部で処理）。
        handProvider.process(frame: frame, interfaceOrientation: interfaceOrientationProvider())
        // ② 毎フレームの静止監視。
        onFrameTick()
    }

    /// 毎フレーム、可動カードの最大速度を静止監視へ供給する（R10-4）。
    func onFrameTick() {
        let speeds = VelocityAggregator.maxSpeeds(cards: cardManager.cards)
        settleObserver.update(maxLinearSpeed: speeds.linear, maxAngularSpeed: speeds.angular)
    }

    // MARK: - Private

    private func handlePunch(_ punch: TablePunchEvent) {
        let power = powerCalculator.power(from: punch.peakVelocity)
        gameState.recordPower(power)
        gameState.incrementTurn() // 1ターン＝台パン1回

        // 衝撃波の中心は盤面そのもの（アンカー位置）にする。
        // 空中の手の画面位置を raycast すると盤面と無関係な点に当たり、半径内にカードが入らないため（#59 実機ログで確認）。
        let center = cardManager.boardCenterWorld
        shockwave.emit(at: center, power: power)
        feedback?.playPunch(power: power)
        settleObserver.onShockEmitted()
    }

    private func handleBoardSettled() {
        let pairs = matchEvaluator.findPairs(faceUp: cardManager.cards)
        guard !pairs.isEmpty else {
            gameState.onPairsMatched(0, remainingPairs: cardManager.remainingPairs)
            return
        }
        cardManager.collect(pairs.flatMap { $0 })
        gameState.onPairsMatched(pairs.count, remainingPairs: cardManager.remainingPairs)
        feedback?.playPairMatched()
    }
}
