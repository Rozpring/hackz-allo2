import Foundation

/// カードの状態。物理静止後にのみ表/伏せが確定する（時間では変化しない, R7-6）。
enum CardState: Equatable {
    case faceDown
    case faceUp
    case collected
}
