// GameCoreChecks — GameCore 純ロジックの実行可能な検証ランナー。
//
// 使い方:
//   swift run GameCoreChecks
// （フル Xcode が無い環境では brew の swift を使う:）
//   /opt/homebrew/opt/swift/bin/swift run GameCoreChecks
//
// 各 issue の検証関数をここから順に呼ぶ。失敗があれば非0で終了する。

print("=== GameCore Checks ===")

runChecks_4_1()

finishChecks()
