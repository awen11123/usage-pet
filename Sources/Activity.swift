import Foundation

/// 通过监测会话日志文件的修改时间，推断当前是「工作中 / 刚结束 / 闲置」。
/// 任一已知 CLI 的 jsonl 被追加时即视为有活动，不依赖当前数据源选择。
enum ActivityState {
    case idle       // 没动静
    case working    // 5 秒内有写入(你或 AI 正在交互)
    case justDone   // 5~30 秒前活跃过，现在静下来
}

enum Activity {
    /// 监测的日志目录。新的 CLI 加进来这里即可。
    static let watchedDirs: [String] = {
        let h = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(h)/.claude/projects", "\(h)/.codex/sessions"]
    }()

    /// 任一目录里最新 jsonl 距今的秒数；找不到返回 nil。
    static func ageOfNewestActivity() -> TimeInterval? {
        let fm = FileManager.default
        var newest: Date?
        for dir in watchedDirs {
            guard let en = fm.enumerator(atPath: dir) else { continue }
            for case let rel as String in en where rel.hasSuffix(".jsonl") {
                let full = dir + "/" + rel
                if let attr = try? fm.attributesOfItem(atPath: full),
                   let d = attr[.modificationDate] as? Date {
                    if newest == nil || d > newest! { newest = d }
                }
            }
        }
        return newest.map { -$0.timeIntervalSinceNow }
    }

    static func currentState() -> ActivityState {
        guard let age = ageOfNewestActivity() else { return .idle }
        if age < 5  { return .working }
        if age < 30 { return .justDone }
        return .idle
    }
}
