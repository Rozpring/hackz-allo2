import Foundation
import Combine

/// アプリ全体の画面状態。権限 → タイトル → 盤面配置 → プレイ → 結果。
enum AppScreen: Equatable {
    case permission
    case title
    case placing
    case playing
    case result
}

/// 画面遷移の単一情報源（R8-1, R8-4）。
/// 権限状態・スタート有無・ゲームフェーズから `ScreenFlow` で表示画面を導出する。
final class AppCoordinator: ObservableObject {
    @Published private(set) var screen: AppScreen = .permission

    private(set) var permission: CameraPermissionState = .notDetermined
    private(set) var hasStarted: Bool = false
    private(set) var phase: GamePhase = .placing

    /// 権限状態の更新を反映する。
    func updatePermission(_ state: CameraPermissionState) {
        permission = state
        recompute()
    }

    /// タイトルの「スタート」押下を反映する。
    func markStarted() {
        hasStarted = true
        recompute()
    }

    /// ゲームフェーズの更新を反映する。
    func updatePhase(_ phase: GamePhase) {
        self.phase = phase
        recompute()
    }

    private func recompute() {
        screen = ScreenFlow.screen(permission: permission, hasStarted: hasStarted, phase: phase)
    }
}
