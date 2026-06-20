import XCTest
import AVFoundation
@testable import TableBangConcentration

final class CameraPermissionTests: XCTestCase {
    func testMapsAuthorizationStatus() {
        XCTAssertEqual(PermissionGate.state(for: .notDetermined), .notDetermined)
        XCTAssertEqual(PermissionGate.state(for: .authorized), .authorized)
        XCTAssertEqual(PermissionGate.state(for: .denied), .denied)
        XCTAssertEqual(PermissionGate.state(for: .restricted), .denied, "restricted も利用不可として扱う")
    }

    func testCanProceedOnlyWhenAuthorized() {
        XCTAssertTrue(PermissionGate.canProceed(.authorized))
        XCTAssertFalse(PermissionGate.canProceed(.denied), "拒否時は盤面生成へ進ませない（R1-2）")
        XCTAssertFalse(PermissionGate.canProceed(.notDetermined))
    }
}
