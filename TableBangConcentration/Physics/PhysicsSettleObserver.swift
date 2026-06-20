import Foundation
import Combine

/// 静止監視の抽象（差し替え可能）。全静止＋表裏確定後に `boardSettled` を発行する。
protocol PhysicsSettleObserving: AnyObject {
    var boardSettled: AnyPublisher<Void, Never> { get }
}

/// 各カードの速度を監視し、静止確定で表/伏せを確定して「盤面静止」を通知する（R5-6, R6-2, R7-3, R7-4, R10-4）。
/// 静止後は疑似スリープ化して物理負荷を下げ、次の台パンで復帰する。
/// 物理が静止しないケースに備えウォッチドッグで強制確定し、クラッシュせず継続する（R10-4）。
final class PhysicsSettleObserver: PhysicsSettleObserving {
    private let cardManager: CardManaging
    private let detector: RestDetector
    private let watchdogFrames: Int

    private let subject = PassthroughSubject<Void, Never>()
    var boardSettled: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }

    private var isMonitoring = false
    private var framesSincePunch = 0

    init(cardManager: CardManaging, config: GameConfig, watchdogFrames: Int = 600) {
        self.cardManager = cardManager
        self.detector = RestDetector(config: config)
        self.watchdogFrames = watchdogFrames
    }

    /// 台パンでインパルスを与えた直後に呼ぶ。静止監視を開始/再武装する。
    func onShockEmitted() {
        detector.reset()
        framesSincePunch = 0
        isMonitoring = true
    }

    /// 毎フレーム、可動カードの最大速度を投入する。静止確定またはウォッチドッグ到達で通知する。
    func update(maxLinearSpeed: Float, maxAngularSpeed: Float) {
        guard isMonitoring else { return }
        framesSincePunch += 1

        let settled = detector.update(maxLinearSpeed: maxLinearSpeed, maxAngularSpeed: maxAngularSpeed)
        let watchdogTripped = framesSincePunch >= watchdogFrames

        if settled || watchdogTripped {
            isMonitoring = false
            confirmFacingAndNotify()
        }
    }

    private func confirmFacingAndNotify() {
        cardManager.cards.forEach { card in
            card.refreshFacing()
            card.sleepPhysics()
        }
        subject.send(())
    }
}
