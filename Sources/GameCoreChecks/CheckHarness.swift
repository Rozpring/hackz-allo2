import Foundation

/// XCTest が使えない環境向けの最小チェックハーネス。
/// 失敗が1件でもあれば実行プロセスは非0で終了する（CI/手動どちらでも判定可能）。
enum CheckHarness {
    nonisolated(unsafe) static var failures = 0
    nonisolated(unsafe) static var total = 0
}

func section(_ name: String) {
    print("\n▶ \(name)")
}

func check(_ condition: Bool, _ message: String, file: StaticString = #file, line: UInt = #line) {
    CheckHarness.total += 1
    if condition {
        print("  ✓ \(message)")
    } else {
        CheckHarness.failures += 1
        print("  ✗ FAIL: \(message)  [\(file):\(line)]")
    }
}

/// 浮動小数の近似一致チェック。
func checkClose(
    _ a: Double,
    _ b: Double,
    accuracy: Double = 1e-9,
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line
) {
    check(abs(a - b) <= accuracy, "\(message) (got \(a), expected ≈ \(b))", file: file, line: line)
}

/// 全チェック終了後に結果を集計し、失敗があれば exit(1)。
func finishChecks() -> Never {
    print("\n──────────────────────────────")
    if CheckHarness.failures == 0 {
        print("ALL CHECKS PASSED (\(CheckHarness.total) checks)")
        exit(0)
    } else {
        print("\(CheckHarness.failures)/\(CheckHarness.total) CHECK(S) FAILED")
        exit(1)
    }
}
