import Foundation

/// 権限状態・スタート有無・ゲームフェーズから表示すべき画面を決める純ロジック（R8-1, R8-4, R1-2）。
enum ScreenFlow {
    static func screen(permission: CameraPermissionState, hasStarted: Bool, phase: GamePhase) -> AppScreen {
        guard PermissionGate.canProceed(permission) else { return .permission }
        guard hasStarted else { return .title }
        switch phase {
        case .placing: return .placing
        case .playing: return .playing
        case .clear, .timeUp: return .result
        }
    }
}
