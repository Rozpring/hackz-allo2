import XCTest
import simd
import RealityKit
@testable import TableBangConcentration

final class CardEntityTests: XCTestCase {
    func testStoresRank() {
        let card = CardEntity(rank: 3, suit: .spades, config: .default)
        XCTAssertEqual(card.rank, 3)
    }

    func testInitiallyFaceDown() {
        // 初期姿勢は伏せ（表面ローカル+Y が下を向く）
        let card = CardEntity(rank: 0, suit: .spades, config: .default)
        XCTAssertEqual(card.state, .faceDown)
        XCTAssertFalse(card.isFaceUp)
        XCTAssertEqual(card.refreshFacing(), .faceDown)
    }

    func testFaceUpWhenUpright() {
        // 表面+Y が上を向く（identity 姿勢）に戻すと、静止確定で表になる
        let card = CardEntity(rank: 0, suit: .spades, config: .default)
        card.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        XCTAssertEqual(card.refreshFacing(), .faceUp)
        XCTAssertTrue(card.isFaceUp)
    }

    func testPhysicsBodyPresentAndSleepWakeTogglesMode() {
        // RealityKit 物理コンポーネントが実環境で実在し、疑似スリープ/復帰で mode が切り替わる
        let card = CardEntity(rank: 0, suit: .spades, config: .default)
        XCTAssertNotNil(card.physicsBody)
        XCTAssertEqual(card.physicsBody?.mode, .dynamic)
        card.sleepPhysics()
        XCTAssertEqual(card.physicsBody?.mode, .static)
        card.wakePhysics()
        XCTAssertEqual(card.physicsBody?.mode, .dynamic)
    }

    func testCollectedCardIgnoresSleepWake() {
        let card = CardEntity(rank: 0, suit: .spades, config: .default)
        card.markCollected()
        card.wakePhysics()
        XCTAssertEqual(card.physicsBody?.mode, .static, "回収済みは復帰しない")
    }

    func testCollectedIsImmutable() {
        // 回収後は表裏確定の対象外
        let card = CardEntity(rank: 0, suit: .spades, config: .default)
        card.markCollected()
        XCTAssertEqual(card.state, .collected)
        card.orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        XCTAssertEqual(card.refreshFacing(), .collected)
    }
}
