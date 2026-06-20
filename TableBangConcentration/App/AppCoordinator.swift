import Foundation
import Combine

/// アプリ全体の画面状態。権限 → 盤面配置 → プレイ → 結果。
enum AppScreen: Equatable {
    case permission
    case placing
    case playing
    case result
}

/// 画面遷移の単一情報源。
final class AppCoordinator: ObservableObject {
    @Published private(set) var screen: AppScreen = .permission

    func go(to screen: AppScreen) {
        self.screen = screen
    }
}
