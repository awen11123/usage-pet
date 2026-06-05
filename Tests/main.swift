import Foundation

// 零依赖测试(不需要 Xcode/XCTest，用 swiftc 编译即可)
var failures = 0
func check(_ cond: Bool, _ name: String) {
    if cond { print("  ✓ \(name)") }
    else { print("  ✗ \(name)"); failures += 1 }
}
func eq<T: Equatable>(_ a: T, _ b: T, _ name: String) { check(a == b, "\(name)  (\(a) == \(b))") }

print("Fmt")
eq(Fmt.bar(0), "░░░░░░░░░░", "bar(0)")
eq(Fmt.bar(100), "██████████", "bar(100)")
eq(Fmt.bar(50).filter { $0 == "█" }.count, 5, "bar(50) 5格")
eq(Fmt.bar(150), "██████████", "bar 越界夹紧")
eq(Fmt.money(3.5, "¥"), "¥3.50", "money")

print("thresholdLevel")
eq(thresholdLevel(79), 0, "79→0")
eq(thresholdLevel(80), 1, "80→1")
eq(thresholdLevel(95), 2, "95→2")

print("Forecast")
eq(Forecast.compute(util: 50, secondsUntilReset: 50, windowSeconds: 100), .projected(100), "半窗50%→预计100%")
eq(Forecast.compute(util: 10, secondsUntilReset: 50, windowSeconds: 100), .projected(20), "半窗10%→预计20%")
if case let .exhausted(eta) = Forecast.compute(util: 50, secondsUntilReset: 75, windowSeconds: 100) {
    check(abs(eta - 25) < 0.5, "1/4窗50%→约25秒用尽 (eta=\(eta))")
} else { check(false, "应为 exhausted") }
eq(Forecast.compute(util: 0, secondsUntilReset: 50, windowSeconds: 100), .none, "0%→none")
eq(Forecast.compute(util: 5, secondsUntilReset: 99, windowSeconds: 100), .none, "刚开窗→none")

print("RelaySnapshot")
var rs = RelaySnapshot(); rs.total = 100; rs.used = 37
eq(rs.remaining, 63, "余=总-用")
eq(rs.usedPercent, 37, "用量%")
var rd = RelaySnapshot(); rd.remainingDirect = 5
eq(rd.remaining, 5, "直给余额")
check(rd.usedPercent == nil, "无总额→无百分比")

print("Codex / Usage")
var cx = CodexSnapshot(); cx.fiveHour = 10; cx.weekly = 80
eq(cx.maxUtilization, 80, "codex max")
let us = UsageSnapshot(fiveHour: 30, sevenDay: 12, opus: nil, sonnet: nil, fiveHourResets: nil, sevenDayResets: nil)
eq(us.maxUtilization, 30, "claude max")

print("ModelInfo.pretty")
eq(ModelInfo.pretty("claude-opus-4-8"), "Opus 4.8", "opus")
eq(ModelInfo.pretty("gpt-5-codex"), "GPT 5 Codex", "gpt")
eq(ModelInfo.pretty("claude-3-5-haiku-20241022"), "3.5 Haiku", "去日期")

print("I18n")
L.lang = "zh"; eq(L.t("refresh"), "立即刷新", "zh")
L.lang = "en"; eq(L.t("refresh"), "Refresh now", "en")
eq(L.t("__missing__"), "__missing__", "缺失回退")
L.lang = "auto"

print("")
if failures == 0 { print("✅ 全部通过") ; exit(0) }
else { print("❌ \(failures) 个失败"); exit(1) }
