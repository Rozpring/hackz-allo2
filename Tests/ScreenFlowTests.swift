import XCTest
@testable import TableBangConcentration

final class ScreenFlowTests: XCTestCase {
    func testPermissionScreenWhenNotAuthorized() {
        XCTAssertEqual(ScreenFlow.screen(permission: .notDetermined, hasStarted: false, phase: .placing), .permission)
        XCTAssertEqual(ScreenFlow.screen(permission: .denied, hasStarted: true, phase: .playing), .permission)
    }

    func testTitleScreenWhenAuthorizedButNotStarted() {
        XCTAssertEqual(ScreenFlow.screen(permission: .authorized, hasStarted: false, phase: .placing), .title)
    }

    func testPlacingScreenAfterStart() {
        XCTAssertEqual(ScreenFlow.screen(permission: .authorized, hasStarted: true, phase: .placing), .placing)
    }

    func testPlayingScreen() {
        XCTAssertEqual(ScreenFlow.screen(permission: .authorized, hasStarted: true, phase: .playing), .playing)
    }

    func testResultScreenOnClear() {
        XCTAssertEqual(ScreenFlow.screen(permission: .authorized, hasStarted: true, phase: .clear), .result)
    }
}
