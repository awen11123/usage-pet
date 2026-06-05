import Foundation

// MARK: - API 响应模型
struct UsageLimit: Codable {
    let utilization: Double
    let resets_at: String?
}

struct UsageResponse: Codable {
    let five_hour: UsageLimit?
    let seven_day: UsageLimit?
    let seven_day_opus: UsageLimit?
    let seven_day_sonnet: UsageLimit?

    func toSnapshot() -> UsageSnapshot {
        UsageSnapshot(
            fiveHour: five_hour?.utilization ?? 0,
            sevenDay: seven_day?.utilization ?? 0,
            opus: seven_day_opus?.utilization,
            sonnet: seven_day_sonnet?.utilization,
            fiveHourResets: five_hour?.resets_at,
            sevenDayResets: seven_day?.resets_at
        )
    }
}

// MARK: - 汇总给 UI 的数据
struct UsageSnapshot {
    let fiveHour: Double
    let sevenDay: Double
    let opus: Double?
    let sonnet: Double?
    let fiveHourResets: String?
    let sevenDayResets: String?

    /// 决定心情的「最紧张」百分比
    var maxUtilization: Double { max(fiveHour, sevenDay) }
}

// MARK: - 工具
enum UsageAPI {
    enum APIError: LocalizedError {
        case message(String)
        case sessionExpired
        var errorDescription: String? {
            switch self {
            case .message(let m): return m
            case .sessionExpired: return "需要登录 Claude"
            }
        }
    }

    /// 调试日志开关。设为 false 关闭日志写入。
    static let logging = false

    static func log(_ msg: String) {
        guard logging else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/.claude/claude-pet.log"
        let line = "[\(Date())] \(msg)\n"
        if let h = FileHandle(forWritingAtPath: path) {
            h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile()
        } else {
            try? line.data(using: .utf8)?.write(to: URL(fileURLWithPath: path))
        }
    }
}
