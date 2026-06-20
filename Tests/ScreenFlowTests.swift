import XCTest
@testable import TableBangConcentration

final class ScreenFlowTests: XCTestCase {
    func testPermissionScreenWhenNotAuthorized() {
        XCTAssertEqual(ScreenFlow.screen(permission: .notDetermined, phase: .placing), .permission)
        XCTAssertEqual(ScreenFlow.screen(permission: .denied, phase: .playing), .permission)
    }

    func testPlacingScreenWhenAuthorizedAndPlacing() {
        XCTAssertEqual(ScreenFlow.screen(permission: .authorized, phase: .placing), .placing)
    }

    func testPlayingScreen() {
        XCTAssertEqual(ScreenFlow.screen(permission: .authorized, phase: .playing), .playing)
    }

    func testResultScreenOnClearOrTimeUp() {
        XCTAssertEqual(ScreenFlow.screen(permission: .authorized, phase: .clear), .result)
        XCTAssertEqual(ScreenFlow.screen(permission: .authorized, phase: .timeUp), .result)
    }
}
