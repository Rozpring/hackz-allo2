import Combine
import CoreGraphics
import Foundation
import GameCore

/// issue #19 (tasks 4.1): 手検出プロバイダ抽象 + 手サンプル型。
/// 完了条件「モック実装で任意の代表点列を発行でき、購読側が受信できる」を検証する。
func runChecks_4_1() {
    section("#19 (4.1) HandLandmarkProvider 抽象 + HandSample")

    var cancellables: Set<AnyCancellable> = []

    // 単一サンプルの発行 → 購読側受信
    do {
        let provider = MockHandLandmarkProvider()
        var received: [HandSample] = []
        provider.samples.sink { received.append($0) }.store(in: &cancellables)

        let sample = HandSample(screenPoint: CGPoint(x: 0.5, y: 0.2), timestamp: 1.0, confidence: 0.9)
        provider.emit(sample)

        check(received == [sample], "単一サンプルを発行すると購読側が同一サンプルを受信する")
    }

    // 時系列の順序保持
    do {
        let provider = MockHandLandmarkProvider()
        var received: [HandSample] = []
        provider.samples.sink { received.append($0) }.store(in: &cancellables)

        provider.emitSeries(yPositions: [0.1, 0.2, 0.3], startTime: 0, interval: 0.1)

        check(received.count == 3, "3サンプル発行で3件受信する")
        check(received.map(\.screenPoint.y) == [0.1, 0.2, 0.3], "y座標が発行順に並ぶ")
        checkClose(received.first?.timestamp ?? -1, 0.0, "先頭サンプルの時刻が startTime")
        checkClose(received.last?.timestamp ?? -1, 0.2, "末尾サンプルの時刻が startTime + interval*(n-1)")
    }

    // 発行前は何も流れない
    do {
        let provider = MockHandLandmarkProvider()
        var received: [HandSample] = []
        provider.samples.sink { received.append($0) }.store(in: &cancellables)

        check(received.isEmpty, "emit する前は購読側に何も流れない")
    }

    cancellables.removeAll()
}
