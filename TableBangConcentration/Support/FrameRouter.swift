import Foundation

/// 1つの入力を複数の消費者へ分配する汎用ルータ（カメラ1フィードの二系統分配, #30）。
/// フレーム型に依存しないため純粋にテスト可能。
final class FrameRouter<Frame> {
    private let consumers: [(Frame) -> Void]

    init(consumers: [(Frame) -> Void]) {
        self.consumers = consumers
    }

    /// 1フレームを全消費者へ順に渡す。
    func route(_ frame: Frame) {
        consumers.forEach { $0(frame) }
    }
}
