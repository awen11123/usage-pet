import Foundation

// MARK: - 纯逻辑(无 AppKit，便于单元测试)

enum Fmt {
    /// 进度条：v 为 0~100
    static func bar(_ v: Double, width: Int = 10) -> String {
        let n = max(0, min(width, Int((v / 100.0 * Double(width)).rounded())))
        return String(repeating: "█", count: n) + String(repeating: "░", count: width - n)
    }
    static func money(_ v: Double, _ currency: String) -> String {
        "\(currency)\(String(format: "%.2f", v))"
    }
    /// 时长 → 紧凑中文/英文(由调用方拼词)；这里只给 (小时,分钟)
    static func hm(_ seconds: Double) -> (h: Int, m: Int) {
        let s = max(0, Int(seconds))
        return (s / 3600, (s % 3600) / 60)
    }
}

/// 阈值等级：0 正常 / 1 警告 / 2 危险
func thresholdLevel(_ util: Double, warn: Double = 80, crit: Double = 95) -> Int {
    util >= crit ? 2 : (util >= warn ? 1 : 0)
}

// MARK: - 燃尽预测
enum Forecast {
    enum Result: Equatable {
        case projected(Int)         // 照此速度，窗口结束时预计百分比
        case exhausted(TimeInterval) // 预计多久后用尽(秒)
        case none
    }
    /// util: 当前用量%；secondsUntilReset: 距重置秒数；windowSeconds: 窗口总长
    static func compute(util: Double, secondsUntilReset: Double,
                        windowSeconds: Double) -> Result {
        guard util > 0, windowSeconds > 0, secondsUntilReset >= 0 else { return .none }
        let elapsed = windowSeconds - secondsUntilReset
        guard elapsed > 0 else { return .none }
        let frac = elapsed / windowSeconds
        guard frac > 0.02 else { return .none }            // 窗口刚开 <2% 时间，样本太少不预测
        let projected = util / frac
        if projected <= 100 { return .projected(Int(projected.rounded())) }
        let ratePerSec = util / elapsed
        guard ratePerSec > 0 else { return .none }
        return .exhausted((100 - util) / ratePerSec)
    }
}

// 已知窗口长度(秒)
enum Window {
    static let fiveHour: Double = 5 * 3600
    static let sevenDay: Double = 7 * 24 * 3600
}
