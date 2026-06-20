import Foundation
import AVFoundation

/// カメラ権限のアプリ内状態。
enum CameraPermissionState: Equatable {
    case notDetermined
    case authorized
    case denied
}

/// 権限判定の純ロジック（R1-1, R1-2）。
enum PermissionGate {
    /// `AVAuthorizationStatus` をアプリ内状態へ写す。`restricted`/`denied` はともに利用不可。
    static func state(for status: AVAuthorizationStatus) -> CameraPermissionState {
        switch status {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    /// 盤面生成へ進んでよいのは許可済みのときのみ（拒否時は進ませない, R1-2）。
    static func canProceed(_ state: CameraPermissionState) -> Bool {
        state == .authorized
    }
}
