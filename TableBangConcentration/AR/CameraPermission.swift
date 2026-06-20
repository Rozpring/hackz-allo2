import Foundation
import AVFoundation

/// カメラ権限の要求・参照の抽象（テスト時に差し替え可能）。
protocol CameraPermissionRequesting: AnyObject {
    var currentState: CameraPermissionState { get }
    func request(_ completion: @escaping (CameraPermissionState) -> Void)
}

/// AVFoundation を用いたカメラ権限の実装（R1-1, R1-2）。
final class CameraPermission: CameraPermissionRequesting {
    var currentState: CameraPermissionState {
        PermissionGate.state(for: AVCaptureDevice.authorizationStatus(for: .video))
    }

    func request(_ completion: @escaping (CameraPermissionState) -> Void) {
        // 既に確定済みなら現在状態を返す。
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .notDetermined else {
            completion(PermissionGate.state(for: status))
            return
        }
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted ? .authorized : .denied)
            }
        }
    }
}
