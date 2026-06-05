import Foundation

/// 通过会话日志的修改时间 + 最后一行类型，推断当前活动状态。
enum ActivityState {
    case idle        // 无动静(>30s)
    case thinking    // Claude 在写回复(最新行 type=assistant，文件活跃)
    case working     // 你/工具在动作(最新行 type=user/tool_use 等，文件活跃)
    case justDone    // 刚结束(5-30s 前活跃过)
}

enum Activity {
    /// 监测的日志目录。新的 CLI 加这里即可。
    static let watchedDirs: [String] = {
        let h = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(h)/.claude/projects", "\(h)/.codex/sessions"]
    }()

    static func currentState() -> ActivityState {
        guard let (path, mtime) = newestJSONL() else { return .idle }
        let age = -mtime.timeIntervalSinceNow
        if age < 5 {
            // 文件正活跃 → 看最后一行是谁的
            let type = lastLineType(of: path) ?? ""
            return (type == "assistant") ? .thinking : .working
        }
        if age < 30 { return .justDone }
        return .idle
    }

    /// 所有目录里最新修改的 jsonl 文件。
    private static func newestJSONL() -> (path: String, mtime: Date)? {
        let fm = FileManager.default
        var newest: (String, Date)?
        for dir in watchedDirs {
            guard let en = fm.enumerator(atPath: dir) else { continue }
            for case let rel as String in en where rel.hasSuffix(".jsonl") {
                let full = dir + "/" + rel
                if let attr = try? fm.attributesOfItem(atPath: full),
                   let d = attr[.modificationDate] as? Date {
                    if newest == nil || d > newest!.1 { newest = (full, d) }
                }
            }
        }
        return newest
    }

    /// 读最后一行的 type 字段。只读文件末尾 8 KB，对大日志也很快。
    private static func lastLineType(of path: String) -> String? {
        guard let h = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? h.close() }
        let size = (try? h.seekToEnd()) ?? 0
        let chunk: UInt64 = min(8192, size)
        try? h.seek(toOffset: size - chunk)
        let data = (try? h.read(upToCount: Int(chunk))) ?? Data()
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            guard let d = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any]
            else { continue }
            if let t = obj["type"] as? String { return t }
        }
        return nil
    }
}
